import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/study_plan_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/backup_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auto_backup_runner.dart';
import 'widgets/focus_flow_export_listener.dart';

void main() {
  // Inter ships with the app; its licence belongs in the licence page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], text);
  });
  runApp(
    ChangeNotifierProvider(
      create: (_) => StudyPlanProvider()..initialize(),
      child: const StudiPlanApp(),
    ),
  );
}

/// Owns the [ThemeService], so the app (and every test that pumps it) gets
/// light/dark switching without extra setup.
class StudiPlanApp extends StatefulWidget {
  const StudiPlanApp({super.key, this.links, this.backup});

  /// Links the app was opened with, see [FocusFlowExportListener]; replaced
  /// in tests.
  final Stream<Uri>? links;

  /// The automatic backup; replaced in tests.
  final BackupService? backup;

  @override
  State<StudiPlanApp> createState() => _StudiPlanAppState();
}

class _StudiPlanAppState extends State<StudiPlanApp> {
  final ThemeService _theme = ThemeService();
  late final BackupService _backup = widget.backup ?? BackupService();

  @override
  void initState() {
    super.initState();
    _theme.load();
    _backup.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    if (widget.backup == null) _backup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(value: _theme),
        ChangeNotifierProvider<BackupService>.value(value: _backup),
      ],
      child: Consumer<ThemeService>(
        builder: (_, theme, __) => MaterialApp(
          title: 'StudiPlan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: FocusFlowExportListener(
            links: widget.links ?? platformAppLinks(),
            child: const AutoBackupRunner(child: _AppRouter()),
          ),
        ),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<StudyPlanProvider>(
      builder: (_, provider, __) {
        if (!provider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return provider.isLoggedIn ? const MainScreen() : const LoginScreen();
      },
    );
  }
}
