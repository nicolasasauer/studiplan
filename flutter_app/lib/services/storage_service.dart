import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/archived_local_plan.dart';
import '../models/local_user_account.dart';
import '../models/study_plan.dart';

class StorageService {
  static const _kPlan = 'sp_plan';
  static const _kUser = 'sp_user';
  static const _kToken = 'sp_token';
  static const _kBaseUrl = 'sp_base_url';
  static const _kLocalMode = 'sp_local_mode';
  static const _kLocalUsers = 'sp_local_users';
  static const _kLocalPendingPlan = 'sp_local_pending_plan';
  static const _kUnsynced = 'sp_unsynced';
  static const _kLocalArchive = 'sp_local_archive';
  static const _kLocalPlanIds = 'sp_local_plan_ids';
  static const _kCurrentLocalPlan = 'sp_current_local_plan';
  static const _kLocalPlanPrefix = 'sp_local_plan_';

  String _planKey({String? username, required bool local}) {
    if (username == null || username.trim().isEmpty) return _kPlan;
    final encoded = base64Url.encode(utf8.encode(username.trim()));
    final scope = local ? 'local' : 'remote';
    return '${_kPlan}_${scope}_$encoded';
  }

  Future<void> savePlan(
    StudyPlan plan, {
    String? username,
    bool local = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _planKey(username: username, local: local),
      jsonEncode(plan.toJson()),
    );
  }

  Future<StudyPlan?> loadPlan({
    String? username,
    bool local = false,
    bool fallbackToLegacy = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planKey(username: username, local: local)) ??
        (fallbackToLegacy ? prefs.getString(_kPlan) : null);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StudyPlan.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Merkt sich, dass der lokale Plan von [username] Änderungen enthält, die
  /// der Server noch nicht bestätigt hat. Überlebt einen Neustart, damit der
  /// nächste Abruf den lokalen Plan nicht mit dem Serverstand überschreibt.
  // ---------------------------------------------------------------------
  // Lokale Pläne: mehrere Pläne ohne Konten, jeder unter seiner ID.
  // ---------------------------------------------------------------------

  /// IDs der lokalen Pläne in Anzeigereihenfolge, oder `null`, wenn noch
  /// nie lokale Pläne gespeichert wurden (dann steht die Umstellung von
  /// lokalen Benutzern aus).
  Future<List<String>?> loadLocalPlanIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kLocalPlanIds);
  }

  Future<void> saveLocalPlanIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLocalPlanIds, ids);
  }

  Future<String?> loadCurrentLocalPlanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrentLocalPlan);
  }

  Future<void> saveCurrentLocalPlanId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_kCurrentLocalPlan);
    } else {
      await prefs.setString(_kCurrentLocalPlan, id);
    }
  }

  Future<void> saveLocalPlan(String id, StudyPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kLocalPlanPrefix$id', jsonEncode(plan.toJson()));
  }

  Future<StudyPlan?> loadLocalPlan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_kLocalPlanPrefix$id');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StudyPlan.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLocalPlan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kLocalPlanPrefix$id');
  }

  /// Entfernt die Daten der früheren lokalen Benutzer (nach der Umstellung
  /// auf lokale Pläne).
  Future<void> clearLegacyLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLocalUsers);
    await prefs.remove(_kLocalArchive);
  }

  Future<void> saveUnsyncedChanges(String username, bool unsynced) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _unsyncedKey(username);
    if (unsynced) {
      await prefs.setBool(key, true);
    } else {
      await prefs.remove(key);
    }
  }

  Future<bool> loadUnsyncedChanges(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unsyncedKey(username)) ?? false;
  }

  String _unsyncedKey(String username) =>
      '${_kUnsynced}_${base64Url.encode(utf8.encode(username.trim()))}';

  Future<void> saveLocalArchive(List<ArchivedLocalPlan> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLocalArchive,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<ArchivedLocalPlan>> loadLocalArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalArchive);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final entry in decoded)
          if (entry is Map)
            ArchivedLocalPlan.fromJson(Map<String, dynamic>.from(entry)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUser(String username, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, username);
    await prefs.setString(_kToken, token);
  }

  Future<Map<String, String>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString(_kUser);
    final token = prefs.getString(_kToken);
    if (user == null || token == null) return null;
    return {'username': user, 'token': token};
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
    await prefs.remove(_kToken);
  }

  Future<void> clearPlan({String? username, bool local = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planKey(username: username, local: local));
  }

  Future<void> clearLegacyPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlan);
  }

  Future<void> savePendingLocalPlan(StudyPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocalPendingPlan, jsonEncode(plan.toJson()));
  }

  Future<StudyPlan?> loadPendingLocalPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalPendingPlan);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StudyPlan.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingLocalPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLocalPendingPlan);
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url);
  }

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? '';
  }

  Future<void> saveLocalMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalMode, enabled);
  }

  Future<bool?> loadLocalMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLocalMode);
  }

  Future<void> saveLocalUsers(List<LocalUserAccount> users) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = users.map((user) => user.toJson()).toList();
    await prefs.setString(_kLocalUsers, jsonEncode(payload));
  }

  Future<List<LocalUserAccount>> loadLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalUsers);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final users = <LocalUserAccount>[];
      for (final entry in decoded) {
        if (entry is Map) {
          final user = LocalUserAccount.fromJson(
            Map<String, dynamic>.from(entry),
          );
          if (user.username.trim().isNotEmpty) {
            users.add(user);
          }
        }
      }
      return users;
    } catch (_) {
      return [];
    }
  }
}
