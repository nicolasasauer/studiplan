import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/study_plan_provider.dart';
import '../services/backup_service.dart';

/// Settings of the automatic backup: folder, interval, and "back up now".
class BackupSettingsDialog extends StatefulWidget {
  const BackupSettingsDialog({super.key});

  @override
  State<BackupSettingsDialog> createState() => _BackupSettingsDialogState();
}

class _BackupSettingsDialogState extends State<BackupSettingsDialog> {
  String? _message;

  Future<void> _chooseFolder() async {
    try {
      await context.read<BackupService>().chooseFolder();
    } on Object catch (e) {
      setState(() => _message = 'Ordner nicht verfügbar: $e');
    }
  }

  Future<void> _backupNow() async {
    final backup = context.read<BackupService>();
    final plans = context.read<StudyPlanProvider>();
    try {
      final snapshots = await plans.backupSnapshots();
      await backup.runNow(snapshots);
      setState(() => _message = snapshots.length == 1
          ? 'Backup gespeichert'
          : '${snapshots.length} Pläne gesichert');
    } on Object catch (e) {
      setState(() => _message = 'Backup fehlgeschlagen: $e');
    }
  }

  String _when(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.'
      '${t.year}, ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupService>();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final last = backup.lastBackup;
    return AlertDialog(
      title: const Text('Automatisches Backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sichert jeden Plan als Exportdatei in einen Ordner deiner '
              'Wahl, z. B. einen Cloud-Ordner. Zurückholen über '
              '„Importieren“. Die letzten ${BackupService.keep} Backups je '
              'Plan bleiben liegen.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('backup-folder'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(backup.folderLabel ?? 'Kein Ordner gewählt'),
              subtitle: const Text('Tippen zum Ändern'),
              onTap: backup.isRunning ? null : _chooseFolder,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BackupInterval>(
                key: const Key('backup-interval'),
                showSelectedIcon: false,
                segments: [
                  for (final interval in BackupInterval.values)
                    ButtonSegment(
                        value: interval, label: Text(interval.label)),
                ],
                selected: {backup.interval},
                onSelectionChanged: (s) => backup.setInterval(s.first),
              ),
            ),
            if (backup.interval != BackupInterval.off &&
                backup.location == null) ...[
              const SizedBox(height: 8),
              Text('Bitte noch einen Ordner wählen.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(
              last == null ? 'Noch kein Backup' : 'Letztes Backup: ${_when(last)}',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            if (backup.lastError != null)
              Text('Letzter Versuch fehlgeschlagen: ${backup.lastError}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, key: const Key('backup-message')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('backup-now'),
          onPressed:
              backup.location == null || backup.isRunning ? null : _backupNow,
          child: const Text('Jetzt sichern'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
