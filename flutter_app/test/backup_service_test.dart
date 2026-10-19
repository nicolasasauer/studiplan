import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/services/backup_service.dart';

class _MemoryFolder implements BackupFolder {
  final files = <String, String>{};

  @override
  Future<List<String>> list() async => files.keys.toList();

  @override
  Future<void> write(String name, String content) async =>
      files[name] = content;

  @override
  Future<void> delete(String name) async => files.remove(name);
}

void main() {
  late _MemoryFolder folder;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    folder = _MemoryFolder();
    now = DateTime(2026, 10, 19, 8);
  });

  Future<BackupService> service() async {
    final s = BackupService(
      openFolder: (_) => folder,
      pickFolder: () async => (location: '/backups', label: 'Backups'),
      clock: () => now,
    );
    await s.load();
    return s;
  }

  const plans = [
    (planName: 'Bachelor Mechatronik', json: '{"a":1}'),
    (planName: 'Master', json: '{"b":2}'),
  ];

  test('nothing is due without a folder or while switched off', () async {
    final s = await service();
    expect(s.isDue, isFalse);
    await s.setInterval(BackupInterval.daily);
    expect(s.isDue, isFalse);
    await s.chooseFolder();
    expect(s.isDue, isTrue);
  });

  test('writes one file per plan, then waits for the interval', () async {
    final s = await service();
    await s.chooseFolder();
    await s.setInterval(BackupInterval.daily);

    await s.runIfDue(() async => plans);
    expect(folder.files.keys, containsAll([
      'studiplan-backup_bachelor-mechatronik_2026-10-19.json',
      'studiplan-backup_master_2026-10-19.json',
    ]));
    expect(s.isDue, isFalse);

    now = now.add(const Duration(hours: 23, minutes: 30));
    expect(s.isDue, isTrue);
    now = DateTime(2026, 10, 20, 7);
    await s.setInterval(BackupInterval.weekly);
    expect(s.isDue, isFalse);
  });

  test('the last backup is remembered across restarts', () async {
    final s = await service();
    await s.chooseFolder();
    await s.setInterval(BackupInterval.weekly);
    await s.runNow(plans);

    final restarted = await service();
    expect(restarted.lastBackup, now);
    expect(restarted.folderLabel, 'Backups');
    expect(restarted.interval, BackupInterval.weekly);
    expect(restarted.isDue, isFalse);
  });

  test('keeps the newest ten per plan and leaves other files alone', () async {
    final s = await service();
    await s.chooseFolder();
    folder.files['notizen.txt'] = 'x';
    for (var day = 1; day <= 12; day++) {
      now = DateTime(2026, 10, day, 8);
      await s.runNow(plans);
    }
    final mechatronik = folder.files.keys
        .where((n) => n.contains('bachelor-mechatronik'))
        .toList()
      ..sort();
    expect(mechatronik, hasLength(BackupService.keep));
    expect(mechatronik.first, endsWith('2026-10-03.json'));
    expect(folder.files, contains('notizen.txt'));
  });

  test('plans with the same name do not overwrite each other', () async {
    final s = await service();
    await s.chooseFolder();
    await s.runNow(const [
      (planName: 'Plan', json: '1'),
      (planName: 'Plan', json: '2'),
    ]);
    expect(folder.files['studiplan-backup_plan_2026-10-19.json'], '1');
    expect(folder.files['studiplan-backup_plan-2_2026-10-19.json'], '2');
  });

  test('a failing folder is reported, not thrown', () async {
    final s = BackupService(
      openFolder: (_) => throw StateError('kein Zugriff'),
      pickFolder: () async => (location: '/weg', label: 'weg'),
      clock: () => now,
    );
    await s.load();
    await s.chooseFolder();
    await s.setInterval(BackupInterval.daily);
    await s.runIfDue(() async => plans);
    expect(s.lastError, contains('kein Zugriff'));
    expect(s.lastBackup, isNull);
  });

  test('file names are safe', () {
    expect(BackupService.slugFor('Bachelor Größe & Übung!'),
        'bachelor-groesse-uebung');
    expect(BackupService.slugFor('***'), 'plan');
  });
}
