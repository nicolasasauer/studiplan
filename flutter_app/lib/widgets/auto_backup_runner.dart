import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/study_plan_provider.dart';
import '../services/backup_service.dart';

/// Runs the automatic backup when it is due: once after the start, once
/// after every return to the app - as soon as a plan is open.
class AutoBackupRunner extends StatefulWidget {
  const AutoBackupRunner({super.key, required this.child});

  final Widget child;

  @override
  State<AutoBackupRunner> createState() => _AutoBackupRunnerState();
}

class _AutoBackupRunnerState extends State<AutoBackupRunner> {
  late final AppLifecycleListener _lifecycle;
  StudyPlanProvider? _plans;
  BackupService? _backup;

  /// Set on start and resume, cleared by the attempt: a failing folder is
  /// tried once per return, not on every change of the plan.
  bool _armed = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      _armed = true;
      _tryBackup();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final plans = context.read<StudyPlanProvider>();
    if (!identical(plans, _plans)) {
      _plans?.removeListener(_tryBackup);
      _plans = plans..addListener(_tryBackup);
    }
    // The settings load in the background; the first check waits for them.
    final backup = context.read<BackupService>();
    if (!identical(backup, _backup)) {
      _backup?.removeListener(_tryBackup);
      _backup = backup..addListener(_tryBackup);
    }
    _tryBackup();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _plans?.removeListener(_tryBackup);
    _backup?.removeListener(_tryBackup);
    super.dispose();
  }

  void _tryBackup() {
    final plans = _plans;
    final backup = _backup;
    if (!_armed || !mounted || plans == null || backup == null) return;
    if (!backup.isLoaded || !plans.isInitialized || !plans.isLoggedIn) return;
    _armed = false;
    backup.runIfDue(plans.backupSnapshots);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
