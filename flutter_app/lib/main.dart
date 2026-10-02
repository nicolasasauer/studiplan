import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/study_plan_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

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
  const StudiPlanApp({super.key});

  @override
  State<StudiPlanApp> createState() => _StudiPlanAppState();
}

class _StudiPlanAppState extends State<StudiPlanApp> {
  final ThemeService _theme = ThemeService();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>.value(
      value: _theme,
      child: Consumer<ThemeService>(
        builder: (_, theme, __) => MaterialApp(
          title: 'StudiPlan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          home: const _AppRouter(),
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
