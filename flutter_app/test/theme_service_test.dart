import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/services/theme_service.dart';
import 'package:studi_plan/theme/app_theme.dart';

void main() {
  group('ThemeService', () {
    test('follows the system until something else is chosen', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ThemeService();
      await service.load();
      expect(service.mode, ThemeMode.system);
    });

    test('remembers the chosen mode across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService().setMode(ThemeMode.dark);

      final restarted = ThemeService();
      await restarted.load();
      expect(restarted.mode, ThemeMode.dark);
    });

    test('ignores an unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'sp_theme_mode': 'sepia'});
      final service = ThemeService();
      await service.load();
      expect(service.mode, ThemeMode.system);
    });
  });

  group('AppTheme', () {
    test('light and dark share the seed but not the brightness', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });

    testWidgets('status colours get deeper on light surfaces', (tester) async {
      late Color onLight;
      late Color onDark;
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            final tone = context.tone(Colors.green);
            if (theme.brightness == Brightness.light) {
              onLight = tone;
            } else {
              onDark = tone;
            }
            return const SizedBox();
          }),
        ));
        // The theme change animates; let it finish before reading.
        await tester.pumpAndSettle();
      }
      expect(onDark, Colors.green);
      expect(onLight, Colors.green.shade800);
    });
  });
}
