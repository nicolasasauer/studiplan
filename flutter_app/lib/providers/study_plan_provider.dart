import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/lecture.dart';
import '../models/semester.dart';
import '../models/study_plan.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Wie mit einem vorhandenen Plan auf dem Server umgegangen wird, wenn ein
/// lokaler Plan zur Synchronisierung freigegeben wird.
enum ServerPlanResolution {
  /// Nachfragen: Hat das Serverkonto schon einen Plan, wird nichts geändert
  /// und [ShareLocalPlanStatus.serverHasPlan] zurückgegeben.
  ask,

  /// Den lokalen Plan hochladen und den Serverplan ersetzen.
  uploadLocal,

  /// Den Serverplan übernehmen.
  keepServer,
}

enum ShareLocalPlanStatus { shared, serverHasPlan, requiresPassword, failed }

class ShareLocalPlanResult {
  const ShareLocalPlanResult(this.status, [this.error]);

  final ShareLocalPlanStatus status;
  final String? error;
}

/// Ein lokaler Plan in der Planliste.
class LocalPlanSummary {
  const LocalPlanSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class StudyPlanProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  String? currentUser;
  String? authToken;
  String _baseUrl = '';
  StudyPlan _plan = StudyPlan();
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _localMode = false;

  /// Im lokalen Modus: der geöffnete Plan und alle lokalen Pläne.
  String? _localPlanId;
  List<LocalPlanSummary> _localPlans = const [];
  Timer? _syncTimer;
  final ApiService Function(String baseUrl) _apiFactory;

  /// Ob der lokale Plan Änderungen enthält, die der Server noch nicht
  /// bestätigt hat. Wird pro Benutzer gespeichert und überlebt Neustarts.
  bool _hasUnsyncedChanges = false;

  /// Zählt lokale Änderungen. Damit wird erkannt, ob sich der Plan während
  /// einer laufenden Anfrage geändert hat.
  int _localRevision = 0;
  Future<bool>? _pushInFlight;

  StudyPlanProvider({
    StorageService? storage,
    ApiService Function(String baseUrl)? apiFactory,
  })  : _storage = storage ?? StorageService(),
        _apiFactory = apiFactory ?? ApiService.new;

  String get baseUrl => _baseUrl;
  StudyPlan get plan => _plan;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  /// Ob ein Plan geöffnet ist: lokal immer, sobald die Pläne geladen sind,
  /// im Servermodus nach der Anmeldung.
  bool get isLoggedIn =>
      _localMode ? _localPlanId != null : currentUser != null;
  String? get currentLocalPlanId => _localPlanId;
  List<LocalPlanSummary> get localPlans => _localPlans;
  bool get localMode => _localMode;
  bool get canUseRemote => !_localMode && _baseUrl.isNotEmpty;
  bool get hasUnsyncedChanges => _hasUnsyncedChanges;

  bool get _canSyncRemote =>
      !_localMode &&
      _baseUrl.isNotEmpty &&
      currentUser != null &&
      authToken != null;

  ApiService get _api => _apiFactory(_baseUrl);

  Future<void> initialize() async {
    try {
      _baseUrl = await _storage.loadBaseUrl();
      _localMode = (await _storage.loadLocalMode()) ?? _baseUrl.isEmpty;

      if (_localMode) {
        await _openLocalPlans();
      } else {
        final savedUser = await _storage.loadUser();
        if (savedUser != null) {
          currentUser = savedUser['username'];
          authToken = savedUser['token'];
          _hasUnsyncedChanges =
              await _storage.loadUnsyncedChanges(currentUser!);
          final saved = await _storage.loadPlan(
            username: currentUser,
            fallbackToLegacy: true,
          );
          if (saved != null) _plan = saved;
        }
      }

      if (isLoggedIn && !_localMode) {
        await refreshPlanFromServer();
        _startSyncTimer();
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.saveBaseUrl(_baseUrl);
    notifyListeners();
  }

  /// Benutzer auf dem Server (nur im Servermodus).
  Future<List<String>> getUsers() async {
    if (_localMode) return const [];
    final r = await _api.getUsers();
    return r.data ?? [];
  }

  Future<({List<String> users, String? error})> getUsersResult() async {
    if (_localMode) return (users: const <String>[], error: null);

    if (_baseUrl.isEmpty) {
      return (
        users: const <String>[],
        error:
            'Server-URL nicht konfiguriert. Bitte Server-Einstellungen prüfen.',
      );
    }

    final r = await _api.getUsers();
    return (users: r.data ?? [], error: r.error);
  }

  Future<String?> login(String username, String? password) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_baseUrl.isEmpty) {
        return 'Server-URL nicht konfiguriert';
      }

      final r = await _api.login(username, password);
      if (r.requiresPassword) return 'REQUIRES_PASSWORD';
      if (r.isSuccess && r.data != null) {
        currentUser = r.data!['username'] as String;
        authToken = r.data!['token'] as String;
        _localMode = false;
        _plan = await _storage.loadPlan(
              username: currentUser,
              fallbackToLegacy: true,
            ) ??
            StudyPlan();
        _hasUnsyncedChanges =
            await _storage.loadUnsyncedChanges(currentUser!);
        await _storage.saveUser(currentUser!, authToken!);
        await _storage.saveLocalMode(false);
        await refreshPlanFromServer();
        _startSyncTimer();
        return null;
      }
      return r.error ?? 'Login fehlgeschlagen';
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createUser(String username, String? password) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_baseUrl.isEmpty) {
        return 'Server-URL nicht konfiguriert';
      }
      final passwordError = ApiService.checkNewPassword(password);
      if (passwordError != null) return passwordError;

      final r = await _api.createUser(username, password);
      if (r.isSuccess && r.data != null) {
        currentUser = r.data!['username'] as String;
        authToken = r.data!['token'] as String;
        _localMode = false;
        await _storage.saveUser(currentUser!, authToken!);
        await _storage.saveLocalMode(false);
        _plan = StudyPlan();
        await _setUnsyncedChanges(false);
        _startSyncTimer();
        return null;
      }
      return r.error ?? 'Erstellen fehlgeschlagen';
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _syncTimer?.cancel();
    currentUser = null;
    authToken = null;
    _plan = StudyPlan();
    _hasUnsyncedChanges = false;
    notifyListeners();
    await _storage.clearUser();
    await _storage.saveLocalMode(_localMode);
  }

  Future<String?> deleteAccount() async {
    if (currentUser == null) return 'Nicht angemeldet';
    _isLoading = true;
    notifyListeners();
    try {
      if (_localMode || authToken == null) return 'Nicht angemeldet';
      final username = currentUser!;
      final r = await _api.deleteUser(username, authToken!);
      if (r.isSuccess) {
        await _storage.clearPlan(username: username);
        await _storage.saveUnsyncedChanges(username, false);
        await logout();
        return null;
      }
      return r.error ?? 'Löschen fehlgeschlagen';
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteUserByName(String username) async {
    _isLoading = true;
    notifyListeners();
    try {
      final r = await _api.deleteUser(username);
      if (r.isSuccess) return null;
      return r.error ?? 'Löschen fehlgeschlagen';
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gibt den geöffneten lokalen Plan zur Synchronisierung frei: meldet sich
  /// am Server an (oder legt ein Konto an), lädt den Plan hoch und wechselt in
  /// den Servermodus.
  ///
  /// Der lokale Plan bleibt in der Planliste des lokalen Modus erhalten. Bis
  /// zur Umstellung (Anmeldung und Prüfung des Serverplans erfolgreich)
  /// ändert sich am Zustand der App nichts.
  Future<ShareLocalPlanResult> shareLocalPlan({
    required String serverUrl,
    required String username,
    String? password,
    required bool createAccount,
    ServerPlanResolution resolution = ServerPlanResolution.ask,
  }) async {
    if (!_localMode || _localPlanId == null) {
      return const ShareLocalPlanResult(
          ShareLocalPlanStatus.failed, 'Kein lokaler Plan geöffnet');
    }
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      return const ShareLocalPlanResult(
          ShareLocalPlanStatus.failed, 'Server-URL fehlt');
    }

    _isLoading = true;
    notifyListeners();
    try {
      final api = _apiFactory(url);
      if (createAccount) {
        final passwordError = ApiService.checkNewPassword(password);
        if (passwordError != null) {
          return ShareLocalPlanResult(
              ShareLocalPlanStatus.failed, passwordError);
        }
      }
      final auth = createAccount
          ? await api.createUser(username.trim(), password)
          : await api.login(username.trim(), password);
      if (auth.requiresPassword) {
        return const ShareLocalPlanResult(
            ShareLocalPlanStatus.requiresPassword, 'Passwort erforderlich');
      }
      if (!auth.isSuccess || auth.data == null) {
        final error = auth.error == 'HTTP 404'
            ? 'Benutzer auf dem Server nicht gefunden'
            : auth.error ?? 'Anmeldung fehlgeschlagen';
        return ShareLocalPlanResult(ShareLocalPlanStatus.failed, error);
      }
      final remoteUser = auth.data!['username'] as String;
      final token = auth.data!['token'] as String;

      // Ein neues Konto hat noch keinen Plan. Bei einem bestehenden Konto
      // wird ein vorhandener Plan nie ohne Rückfrage ersetzt.
      StudyPlan? serverPlan;
      if (!createAccount) {
        final r = await api.getPlan(remoteUser, token);
        if (r.isSuccess && r.data != null) {
          serverPlan = StudyPlan.fromJson(r.data!);
        } else if (r.error != 'HTTP 404') {
          return ShareLocalPlanResult(ShareLocalPlanStatus.failed,
              'Plan auf dem Server nicht lesbar: ${r.error}');
        }
      }
      final serverHasPlan = serverPlan?.isEffectivelyConfigured ?? false;
      if (serverHasPlan && resolution == ServerPlanResolution.ask) {
        return const ShareLocalPlanResult(ShareLocalPlanStatus.serverHasPlan);
      }
      final useServerPlan =
          serverHasPlan && resolution == ServerPlanResolution.keepServer;

      // Ab hier: in den Servermodus wechseln. Der lokale Plan bleibt
      // gespeichert.
      final localPlan = StudyPlan.fromJson(_plan.toJson());
      _syncTimer?.cancel();
      _localPlanId = null;
      _baseUrl = url;
      _localMode = false;
      currentUser = remoteUser;
      authToken = token;
      await _storage.saveBaseUrl(url);
      await _storage.saveLocalMode(false);
      await _storage.saveUser(remoteUser, token);

      if (useServerPlan) {
        _plan = serverPlan!;
        _localRevision++;
        await _storage.savePlan(_plan, username: remoteUser);
        await _setUnsyncedChanges(false);
      } else {
        _plan = localPlan;
        await _save();
      }
      _startSyncTimer();
      return const ShareLocalPlanResult(ShareLocalPlanStatus.shared);
    } catch (e) {
      return ShareLocalPlanResult(ShareLocalPlanStatus.failed, e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Wechselt in den lokalen Modus und öffnet den zuletzt benutzten
  /// lokalen Plan (oder legt den ersten an).
  Future<void> enterLocalMode() async {
    _syncTimer?.cancel();
    _localMode = true;
    currentUser = null;
    authToken = null;
    _plan = StudyPlan();
    _hasUnsyncedChanges = false;
    await _storage.clearUser();
    await _storage.saveLocalMode(true);
    await _openLocalPlans();
    notifyListeners();
  }

  Future<void> leaveLocalMode() async {
    _syncTimer?.cancel();
    _localMode = false;
    _localPlanId = null;
    currentUser = null;
    authToken = null;
    _plan = StudyPlan();
    _hasUnsyncedChanges = false;
    notifyListeners();
    await _storage.clearUser();
    await _storage.saveLocalMode(false);
  }

  /// Holt den Plan vom Server und ersetzt den lokalen damit.
  ///
  /// Ausstehende lokale Änderungen werden vorher hochgeladen. Gelingt das
  /// nicht (z. B. offline), bleibt der lokale Plan unverändert, statt mit dem
  /// älteren Serverstand überschrieben zu werden.
  Future<void> refreshPlanFromServer() async {
    if (!_canSyncRemote) return;

    if (_hasUnsyncedChanges || _pushInFlight != null) {
      if (!await _pushPendingPlan()) return;
    }

    final username = currentUser!;
    final revision = _localRevision;
    final r = await _api.getPlan(username, authToken!);
    // Während der Anfrage lokal geändert oder Benutzer gewechselt: Die
    // Antwort ist veraltet und darf den lokalen Plan nicht ersetzen.
    if (currentUser != username ||
        revision != _localRevision ||
        _hasUnsyncedChanges) {
      return;
    }
    if (r.isSuccess && r.data != null) {
      try {
        _plan = StudyPlan.fromJson(r.data!);
        await _storage.savePlan(_plan, username: username);
        notifyListeners();
      } catch (e) {
        print('Failed to parse server plan: $e');
      }
    } else if (r.error != null) {
      print('Plan refresh failed: ${r.error}');
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshPlanFromServer(),
    );
  }

  Future<void> _save() async {
    _localRevision++;
    if (_localMode) {
      final id = _localPlanId;
      if (id != null) {
        await _storage.saveLocalPlan(id, _plan);
        _updateLocalPlanName(id, _plan.planName);
      }
    } else {
      await _storage.savePlan(_plan, username: currentUser);
    }
    if (_canSyncRemote) {
      await _setUnsyncedChanges(true);
      notifyListeners();
      await _pushPendingPlan();
    }
    notifyListeners();
  }

  Future<void> _setUnsyncedChanges(bool unsynced) async {
    _hasUnsyncedChanges = unsynced;
    final username = currentUser;
    if (username != null && !_localMode) {
      await _storage.saveUnsyncedChanges(username, unsynced);
    }
  }

  /// Lädt den lokalen Plan hoch, bis der Server den aktuellen Stand bestätigt
  /// hat. Läuft schon ein Upload, wird auf ihn gewartet. Gibt `true` zurück,
  /// wenn danach nichts mehr aussteht.
  Future<bool> _pushPendingPlan() =>
      _pushInFlight ??= _runPush().whenComplete(() => _pushInFlight = null);

  Future<bool> _runPush() async {
    while (_canSyncRemote) {
      final username = currentUser!;
      final revision = _localRevision;
      final result =
          await _api.savePlan(username, authToken!, _plan.toJson());
      if (currentUser != username) return false;
      if (!result.isSuccess) {
        print('Remote save failed, will retry: ${result.error}');
        return false;
      }
      // Während des Uploads lokal geändert: neuen Stand hochladen.
      if (revision != _localRevision) continue;
      await _setUnsyncedChanges(false);
      // Änderung während des Speicherns der Markierung: wieder ausstehend.
      if (revision != _localRevision) {
        await _setUnsyncedChanges(true);
        continue;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> initializePlan(
    String name,
    int regularSemesters,
    String startSeason, {
    int? targetEcts,
  }) async {
    final semesters = <Semester>[];
    String season = startSeason;
    for (int i = 1; i <= regularSemesters; i++) {
      // Zufällige IDs, damit unabhängig angelegte Pläne verschiedener Geräte
      // beim späteren Zusammenführen nicht dieselben Semester-IDs tragen.
      semesters.add(Semester(id: _uuid.v4(), number: i, season: season));
      season = season == 'winter' ? 'summer' : 'winter';
    }

    _plan = StudyPlan(
      planName: name,
      regularSemesters: regularSemesters,
      startSeason: startSeason,
      isConfigured: true,
      targetEcts: targetEcts,
      semesters: semesters,
    );
    await _save();
  }

  /// Saves the settings dialog in one go, so the server gets one push.
  Future<void> updatePlanSettings({
    required bool weightAverageGradeByEcts,
    required int? targetEcts,
  }) async {
    _plan.weightAverageGradeByEcts = weightAverageGradeByEcts;
    _plan.targetEcts = StudyPlan.normalizeTargetEcts(targetEcts);
    await _save();
  }

  Future<void> updatePlanName(String name) async {
    _plan.planName = name.trim().isEmpty ? StudyPlan.defaultPlanName : name.trim();
    await _save();
  }

  Future<void> updateGradeWeighting(bool enabled) async {
    _plan.weightAverageGradeByEcts = enabled;
    await _save();
  }

  Future<void> addSemester() async {
    try {
      final lastNum = _plan.semesters.isEmpty
          ? 0
          : _plan.semesters.map((s) => s.number).reduce((a, b) => a > b ? a : b);
      final lastSeason = _plan.semesters.isEmpty
          ? (_plan.startSeason == 'winter' ? 'summer' : 'winter')
          : _plan.semesters.last.season;
      final newSeason = lastSeason == 'winter' ? 'summer' : 'winter';
      _plan.semesters.add(
        Semester(id: _uuid.v4(), number: lastNum + 1, season: newSeason),
      );
      await _save();
    } catch (e) {
      print('Error in addSemester: $e');
      rethrow;
    }
  }

  Future<void> removeSemester(String semesterId) async {
    try {
      final sem = _plan.semesters.firstWhereOrNull((s) => s.id == semesterId);
      if (sem == null) {
        print('Warning: Semester $semesterId not found for removal');
        return;
      }
      for (final l in sem.lectures) {
        _plan.parkingLot.add(l.copyWith(semesterId: null));
      }
      _plan.semesters.removeWhere((s) => s.id == semesterId);
      await _save();
    } catch (e) {
      print('Error in removeSemester: $e');
      rethrow;
    }
  }

  Future<void> addLecture(Lecture lecture, String? semesterId) async {
    try {
      if (semesterId != null) {
        final sem = _plan.semesters.firstWhereOrNull((s) => s.id == semesterId);
        if (sem == null) {
          print('Warning: Semester $semesterId not found for adding lecture');
          return;
        }
        sem.lectures.add(lecture.copyWith(semesterId: semesterId));
      } else {
        _plan.parkingLot.add(lecture.copyWith(semesterId: null));
      }
      await _save();
    } catch (e) {
      print('Error in addLecture: $e');
      rethrow;
    }
  }

  Future<void> updateLecture(Lecture updated) async {
    try {
      final location = _findLectureLocation(updated.id);
      if (location == null) {
        print('Warning: Lecture ${updated.id} not found for update');
        return;
      }

      if (location.semesterId == updated.semesterId) {
        if (location.semesterId != null) {
          final sem = _plan.semesters.firstWhereOrNull((s) => s.id == location.semesterId);
          if (sem != null && location.index < sem.lectures.length) {
            sem.lectures[location.index] = updated.copyWith(
              semesterId: location.semesterId,
            );
          }
        } else if (location.index < _plan.parkingLot.length) {
          _plan.parkingLot[location.index] = updated.copyWith(semesterId: null);
        }
      } else {
        _removeLectureAt(location);
        _insertLecture(updated, updated.semesterId);
      }

      await _save();
    } catch (e) {
      print('Error in updateLecture: $e');
      rethrow;
    }
  }

  Future<void> removeLecture(String id, String? semesterId) async {
    final location = _findLectureLocation(id);
    if (location == null) return;
    _removeLectureAt(location);
    await _save();
  }

  Future<void> toggleLecturePassed(String id, String? semesterId) async {
    try {
      final location = _findLectureLocation(id);
      if (location == null) {
        print('Warning: Lecture $id not found for toggle passed');
        return;
      }

      if (location.semesterId != null) {
        final sem = _plan.semesters.firstWhereOrNull((s) => s.id == location.semesterId);
        if (sem != null && location.index < sem.lectures.length) {
          final lecture = sem.lectures[location.index];
          sem.lectures[location.index] = lecture.copyWith(passed: !lecture.passed);
        }
      } else if (location.index < _plan.parkingLot.length) {
        final lecture = _plan.parkingLot[location.index];
        _plan.parkingLot[location.index] =
            lecture.copyWith(passed: !lecture.passed);
      }

      await _save();
    } catch (e) {
      print('Error in toggleLecturePassed: $e');
      rethrow;
    }
  }

  /// Where [lectureId] lives right now: its semester (`null` for the parking
  /// lot) and its position there, or `null` if the plan has no such lecture.
  ({String? semesterId, int index})? locateLecture(String lectureId) =>
      _findLectureLocation(lectureId);

  /// Moves [lectureId] into [toSemesterId], or onto the parking lot when it
  /// is `null`, from wherever the lecture is *now* - not where a drag started:
  /// the 30-second sync may have replaced the plan in between.
  ///
  /// Appends, or inserts at [index] (clamped) when given, e.g. to undo a
  /// move. Returns `false` and changes nothing when the lecture or the target
  /// semester is gone, or when the lecture already sits there.
  Future<bool> moveLecture(
    String lectureId,
    String? toSemesterId, {
    int? index,
  }) async {
    final from = locateLecture(lectureId);
    if (from == null) return false;

    final List<Lecture> target;
    if (toSemesterId == null) {
      target = _plan.parkingLot;
    } else {
      final sem =
          _plan.semesters.firstWhereOrNull((s) => s.id == toSemesterId);
      if (sem == null) return false;
      target = sem.lectures;
    }

    final source = from.semesterId == null
        ? _plan.parkingLot
        : _plan.semesters.firstWhere((s) => s.id == from.semesterId).lectures;
    if (identical(source, target) &&
        (index == null || index == from.index)) {
      return false;
    }

    final lecture = source.removeAt(from.index);
    final moved = lecture.copyWith(semesterId: toSemesterId);
    final at = (index ?? target.length).clamp(0, target.length);
    target.insert(at, moved);
    await _save();
    return true;
  }

  Future<void> moveLectureToSemester(
    String lectureId,
    String? fromSemesterId,
    String toSemesterId,
  ) async {
    Lecture? lecture;
    if (fromSemesterId != null) {
      final sem = _plan.semesters.firstWhereOrNull((s) => s.id == fromSemesterId);
      if (sem != null) {
        final idx = sem.lectures.indexWhere((l) => l.id == lectureId);
        if (idx != -1) {
          lecture = sem.lectures.removeAt(idx);
        }
      }
    } else {
      final idx = _plan.parkingLot.indexWhere((l) => l.id == lectureId);
      if (idx != -1) {
        lecture = _plan.parkingLot.removeAt(idx);
      }
    }

    if (lecture == null) return;

    final toSem = _plan.semesters.firstWhereOrNull((s) => s.id == toSemesterId);
    if (toSem == null) {
      print('Warning: target semester $toSemesterId not found for lecture move');
      if (fromSemesterId != null) {
        final origin = _plan.semesters.firstWhereOrNull((s) => s.id == fromSemesterId);
        if (origin != null) {
          origin.lectures.add(lecture);
        } else {
          _plan.parkingLot.add(lecture.copyWith(semesterId: null));
        }
      } else {
        _plan.parkingLot.add(lecture.copyWith(semesterId: null));
      }
      await _save();
      return;
    }

    toSem.lectures.add(lecture.copyWith(semesterId: toSemesterId));
    await _save();
  }

  Future<void> moveLectureToParkingLot(
    String lectureId,
    String fromSemesterId,
  ) async {
    final sem = _plan.semesters.firstWhereOrNull((s) => s.id == fromSemesterId);
    if (sem == null) return;
    final idx = sem.lectures.indexWhere((l) => l.id == lectureId);
    if (idx == -1) return;
    final lecture = sem.lectures.removeAt(idx);
    _plan.parkingLot.add(lecture.copyWith(semesterId: null));
    await _save();
  }

  Future<void> sortSemesterLectures(String semesterId, String by) async {
    final sem = _plan.semesters.firstWhereOrNull((s) => s.id == semesterId);
    if (sem == null) return;
    if (by == 'date') {
      sem.lectures.sort((a, b) {
        if (a.examDate == null && b.examDate == null) return 0;
        if (a.examDate == null) return 1;
        if (b.examDate == null) return -1;
        return a.examDate!.compareTo(b.examDate!);
      });
    } else {
      sem.lectures.sort((a, b) => b.ects.compareTo(a.ects));
    }
    await _save();
  }

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(_plan.toJson());

  Future<String?> importJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return 'Import fehlgeschlagen: Ungültiges JSON-Format';
      }
      final imported = StudyPlan.fromJson(Map<String, dynamic>.from(decoded));
      if (_localMode) {
        // Lokal kommt ein importierter Plan neben die vorhandenen, statt den
        // geöffneten zu ersetzen.
        await createLocalPlan(from: imported);
      } else {
        _plan = imported;
        await _save();
      }
      return null;
    } catch (e) {
      return 'Import fehlgeschlagen: $e';
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Lokale Pläne
  // ---------------------------------------------------------------------

  /// Legt einen neuen lokalen Plan an (leer oder aus [from]) und öffnet ihn.
  /// Ein leerer Plan ist noch nicht eingerichtet, die Oberfläche fragt dann
  /// nach Name und Semestern.
  Future<String> createLocalPlan({StudyPlan? from}) async {
    final id = _uuid.v4();
    final plan = from ?? StudyPlan();
    await _storage.saveLocalPlan(id, plan);
    final ids = [..._localPlans.map((p) => p.id), id];
    await _storage.saveLocalPlanIds(ids);
    _localPlans = [
      ..._localPlans,
      LocalPlanSummary(id: id, name: plan.planName),
    ];
    await _activateLocalPlan(id, plan);
    notifyListeners();
    return id;
  }

  /// Öffnet einen anderen lokalen Plan.
  Future<void> switchLocalPlan(String id) async {
    if (!_localMode || id == _localPlanId) return;
    if (!_localPlans.any((p) => p.id == id)) return;
    final plan = await _storage.loadLocalPlan(id) ?? StudyPlan();
    await _activateLocalPlan(id, plan);
    notifyListeners();
  }

  /// Löscht einen lokalen Plan. War er geöffnet, wird der nächste geöffnet;
  /// war es der letzte, wird ein neuer leerer Plan angelegt.
  Future<void> deleteLocalPlan(String id) async {
    if (!_localPlans.any((p) => p.id == id)) return;
    final remaining = _localPlans.where((p) => p.id != id).toList();
    // Erst die Liste ohne den Plan speichern, dann seine Daten löschen.
    await _storage.saveLocalPlanIds(remaining.map((p) => p.id).toList());
    await _storage.clearLocalPlan(id);
    _localPlans = remaining;
    if (id == _localPlanId) {
      if (remaining.isEmpty) {
        await createLocalPlan();
        return;
      }
      final next = remaining.first;
      await _activateLocalPlan(
          next.id, await _storage.loadLocalPlan(next.id) ?? StudyPlan());
    }
    notifyListeners();
  }

  Future<void> _activateLocalPlan(String id, StudyPlan plan) async {
    _localPlanId = id;
    _plan = plan;
    _localRevision++;
    await _storage.saveCurrentLocalPlanId(id);
  }

  void _updateLocalPlanName(String id, String name) {
    _localPlans = [
      for (final p in _localPlans)
        p.id == id ? LocalPlanSummary(id: id, name: name) : p,
    ];
  }

  /// Lädt die lokalen Pläne (nach der Umstellung von lokalen Benutzern) und
  /// öffnet den zuletzt benutzten. Gibt es noch keinen, wird einer angelegt.
  Future<void> _openLocalPlans() async {
    final ids = await _storage.loadLocalPlanIds() ??
        await _migrateLocalUsersToPlans();
    final summaries = <LocalPlanSummary>[];
    final plans = <String, StudyPlan>{};
    for (final id in ids) {
      final plan = await _storage.loadLocalPlan(id);
      if (plan == null) continue;
      plans[id] = plan;
      summaries.add(LocalPlanSummary(id: id, name: plan.planName));
    }
    _localPlans = summaries;
    if (summaries.isEmpty) {
      _localPlanId = null;
      await createLocalPlan();
      return;
    }
    final saved = await _storage.loadCurrentLocalPlanId();
    final id = plans.containsKey(saved) ? saved! : summaries.first.id;
    await _activateLocalPlan(id, plans[id]!);
  }

  /// Einmalige Umstellung: Aus jedem früheren lokalen Benutzer (und aus dem
  /// Archiv freigegebener Pläne) wird ein lokaler Plan. Lokale Passwörter
  /// entfallen. Die neuen Pläne werden vollständig gespeichert, bevor die
  /// alten Daten gelöscht werden.
  Future<List<String>> _migrateLocalUsersToPlans() async {
    final ids = <String>[];
    String? currentId;
    final savedUser = await _storage.loadUser();
    final savedLocalUser = savedUser?['token'] == null
        ? null
        : savedUser!['token']!.startsWith('local-session:')
            ? savedUser['username']
            : null;

    Future<String> adopt(StudyPlan plan, String fallbackName) async {
      if (plan.planName == StudyPlan.defaultPlanName &&
          fallbackName.trim().isNotEmpty) {
        plan.planName = fallbackName.trim();
      }
      final id = _uuid.v4();
      await _storage.saveLocalPlan(id, plan);
      ids.add(id);
      return id;
    }

    final users = await _storage.loadLocalUsers();
    for (final user in users) {
      final plan = await _storage.loadPlan(
        username: user.username,
        local: true,
        fallbackToLegacy: false,
      );
      if (plan == null) continue;
      final id = await adopt(plan, user.username);
      if (user.username == savedLocalUser) currentId = id;
    }
    for (final entry in await _storage.loadLocalArchive()) {
      await adopt(entry.plan, entry.username);
    }
    final pending = await _storage.loadPendingLocalPlan();
    if (pending != null) {
      await adopt(pending, '');
    } else if (users.isEmpty) {
      // Sehr alter Stand: ein einzelner Plan ohne Benutzer.
      final legacy = await _storage.loadPlan();
      if (legacy != null) await adopt(legacy, '');
    }

    await _storage.saveLocalPlanIds(ids);
    await _storage.saveCurrentLocalPlanId(currentId);

    for (final user in users) {
      await _storage.clearPlan(username: user.username, local: true);
    }
    await _storage.clearLegacyLocalUsers();
    await _storage.clearPendingLocalPlan();
    if (users.isEmpty && pending == null) await _storage.clearLegacyPlan();
    if (savedLocalUser != null) await _storage.clearUser();
    return ids;
  }

  ({String? semesterId, int index})? _findLectureLocation(String lectureId) {
    for (final semester in _plan.semesters) {
      final index =
          semester.lectures.indexWhere((lecture) => lecture.id == lectureId);
      if (index != -1) {
        return (semesterId: semester.id, index: index);
      }
    }

    final parkingIndex =
        _plan.parkingLot.indexWhere((lecture) => lecture.id == lectureId);
    if (parkingIndex != -1) {
      return (semesterId: null, index: parkingIndex);
    }

    return null;
  }

  void _removeLectureAt(({String? semesterId, int index}) location) {
    if (location.semesterId != null) {
      final semester =
          _plan.semesters.firstWhere((s) => s.id == location.semesterId);
      semester.lectures.removeAt(location.index);
    } else {
      _plan.parkingLot.removeAt(location.index);
    }
  }

  void _insertLecture(Lecture lecture, String? semesterId) {
    if (semesterId != null) {
      final semesterIndex =
          _plan.semesters.indexWhere((s) => s.id == semesterId);
      if (semesterIndex != -1) {
        _plan.semesters[semesterIndex].lectures.add(
          lecture.copyWith(semesterId: semesterId),
        );
        return;
      }
    }

    _plan.parkingLot.add(lecture.copyWith(semesterId: null));
  }
}
