import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How often the automatic backup runs.
enum BackupInterval {
  off('Aus', null),
  daily('Täglich', Duration(days: 1)),
  weekly('Wöchentlich', Duration(days: 7));

  const BackupInterval(this.label, this.every);

  final String label;

  /// Time between two backups; null when switched off.
  final Duration? every;

  static BackupInterval fromName(String? name) => BackupInterval.values
      .firstWhere((i) => i.name == name, orElse: () => BackupInterval.off);
}

/// A folder the backup writes to: a plain directory on the desktop, a
/// Storage Access Framework tree on Android.
abstract interface class BackupFolder {
  /// Names of the files directly in the folder.
  Future<List<String>> list();

  /// Writes [content] to [name], replacing a file of that name.
  Future<void> write(String name, String content);

  Future<void> delete(String name);
}

/// [BackupFolder] for a directory path (Windows, Linux, macOS).
class DirectoryBackupFolder implements BackupFolder {
  DirectoryBackupFolder(this.path);

  final String path;

  @override
  Future<List<String>> list() async {
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    return [
      await for (final entry in dir.list())
        if (entry is File) entry.uri.pathSegments.last,
    ];
  }

  @override
  Future<void> write(String name, String content) async {
    await Directory(path).create(recursive: true);
    await File('$path${Platform.pathSeparator}$name').writeAsString(content);
  }

  @override
  Future<void> delete(String name) async {
    final file = File('$path${Platform.pathSeparator}$name');
    if (await file.exists()) await file.delete();
  }
}

/// [BackupFolder] for an Android tree URI, through MainActivity's channel.
class SafBackupFolder implements BackupFolder {
  SafBackupFolder(this.uri);

  static const channel = MethodChannel('studiplan/backup_folder');

  final String uri;

  @override
  Future<List<String>> list() async =>
      (await channel.invokeListMethod<String>('list', {'uri': uri})) ??
      const [];

  @override
  Future<void> write(String name, String content) => channel
      .invokeMethod('write', {'uri': uri, 'name': name, 'content': content});

  @override
  Future<void> delete(String name) =>
      channel.invokeMethod('delete', {'uri': uri, 'name': name});
}

/// One plan to back up: its name (for the file name) and its export JSON.
typedef BackupSnapshot = ({String planName, String json});

/// The automatic backup: every plan as an export file in a folder the user
/// picked, daily or weekly, checked when the app starts or comes back.
///
/// Each backup is a normal export (`Plan importieren` reads it back), named
/// `studiplan-backup_<plan>_<date>.json`; the newest [keep] per plan stay.
class BackupService extends ChangeNotifier {
  BackupService({
    BackupFolder Function(String location)? openFolder,
    Future<({String location, String label})?> Function()? pickFolder,
    DateTime Function()? clock,
  })  : _openFolder = openFolder ?? _platformFolder,
        _pickFolder = pickFolder ?? _platformPick,
        _clock = clock ?? DateTime.now;

  static const _kLocation = 'sp_backup_location';
  static const _kLabel = 'sp_backup_label';
  static const _kInterval = 'sp_backup_interval';
  static const _kLast = 'sp_backup_last';

  /// Backups kept per plan; older ones are deleted.
  static const keep = 10;

  static const filePrefix = 'studiplan-backup_';

  final BackupFolder Function(String location) _openFolder;
  final Future<({String location, String label})?> Function() _pickFolder;
  final DateTime Function() _clock;

  String? _location;
  String? _label;
  BackupInterval _interval = BackupInterval.off;
  DateTime? _lastBackup;
  String? _lastError;
  bool _running = false;
  bool _loaded = false;

  /// Whether [load] has read the settings; nothing is due before that.
  bool get isLoaded => _loaded;

  /// Path or tree URI of the folder; null until one is picked.
  String? get location => _location;

  /// The folder as shown to the user.
  String? get folderLabel => _label;
  BackupInterval get interval => _interval;
  DateTime? get lastBackup => _lastBackup;

  /// Why the last automatic backup failed, or null.
  String? get lastError => _lastError;
  bool get isRunning => _running;

  /// Android needs its own folder access, desktop a directory; the web
  /// app and iOS have no automatic backup.
  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _location = prefs.getString(_kLocation);
    _label = prefs.getString(_kLabel);
    _interval = BackupInterval.fromName(prefs.getString(_kInterval));
    final last = prefs.getInt(_kLast);
    _lastBackup =
        last == null ? null : DateTime.fromMillisecondsSinceEpoch(last);
    _loaded = true;
    notifyListeners();
  }

  /// Lets the user pick the folder. False when cancelled.
  Future<bool> chooseFolder() async {
    final picked = await _pickFolder();
    if (picked == null) return false;
    _location = picked.location;
    _label = picked.label;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocation, picked.location);
    await prefs.setString(_kLabel, picked.label);
    notifyListeners();
    return true;
  }

  Future<void> setInterval(BackupInterval interval) async {
    _interval = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInterval, interval.name);
    notifyListeners();
  }

  /// Whether an automatic backup is due: switched on, a folder picked, and
  /// the interval passed since the last one.
  bool get isDue {
    final every = _interval.every;
    if (every == null || _location == null) return false;
    final last = _lastBackup;
    // A little slack, so "daily" at 8:00 still runs at 7:55 the next day.
    return last == null ||
        _clock().difference(last) >= every - const Duration(hours: 1);
  }

  /// Runs the backup when [isDue]. Errors are kept in [lastError] instead
  /// of thrown: a failing backup must not get in the way of the app.
  Future<void> runIfDue(
      Future<List<BackupSnapshot>> Function() snapshots) async {
    if (!isDue || _running) return;
    try {
      await runNow(await snapshots());
    } on Object catch (e) {
      _lastError = '$e';
      notifyListeners();
    }
  }

  /// Writes one file per plan now and prunes old ones. Throws when the
  /// folder cannot be written.
  Future<void> runNow(List<BackupSnapshot> snapshots) async {
    final location = _location;
    if (location == null) throw StateError('Kein Backup-Ordner gewählt');
    _running = true;
    notifyListeners();
    try {
      final folder = _openFolder(location);
      final now = _clock();
      final existing = await folder.list();
      final used = <String>{};
      for (final snapshot in snapshots) {
        var slug = slugFor(snapshot.planName);
        // Two plans with the same name must not overwrite each other.
        for (var n = 2; used.contains(slug); n++) {
          slug = '${slugFor(snapshot.planName)}-$n';
        }
        used.add(slug);
        await folder.write(fileName(slug, now), snapshot.json);
        await _prune(folder, existing, slug, now);
      }
      _lastBackup = now;
      _lastError = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLast, now.millisecondsSinceEpoch);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// Deletes all but the newest [keep] backups of [slug]. The date in the
  /// name sorts them, [existing] plus today's file are the candidates.
  Future<void> _prune(BackupFolder folder, List<String> existing,
      String slug, DateTime now) async {
    final prefix = '$filePrefix${slug}_';
    final dated = RegExp('^${RegExp.escape(prefix)}\\d{4}-\\d{2}-\\d{2}\\.json\$');
    final names = {
      ...existing.where(dated.hasMatch),
      fileName(slug, now),
    }.toList()
      ..sort();
    if (names.length <= keep) return;
    for (final name in names.take(names.length - keep)) {
      await folder.delete(name);
    }
  }

  /// `studiplan-backup_bachelor-mechatronik_2026-10-19.json`
  static String fileName(String slug, DateTime day) =>
      '$filePrefix${slug}_${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}.json';

  /// File-name-safe plan name: lower case, umlauts spelled out, anything
  /// else a dash.
  static String slugFor(String planName) {
    final text = planName
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return text.isEmpty ? 'plan' : text;
  }

  static BackupFolder _platformFolder(String location) =>
      !kIsWeb && Platform.isAndroid
          ? SafBackupFolder(location)
          : DirectoryBackupFolder(location);

  static Future<({String location, String label})?> _platformPick() async {
    if (!kIsWeb && Platform.isAndroid) {
      final picked = await SafBackupFolder.channel
          .invokeMapMethod<String, String>('pickFolder');
      if (picked == null) return null;
      return (location: picked['uri']!, label: picked['name']!);
    }
    final path =
        await FilePicker.getDirectoryPath(dialogTitle: 'Backup-Ordner wählen');
    if (path == null) return null;
    return (location: path, label: path);
  }
}
