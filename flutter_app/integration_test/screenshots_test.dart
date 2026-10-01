import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studi_plan/main.dart' as app;

/// Opens the "Neue Veranstaltung" dialog from the semester at [semesterIndex],
/// fills in [name] and [ects], and saves.
Future<void> _addLecture(
  WidgetTester tester,
  int semesterIndex,
  String name,
  String ects,
) async {
  await tester.tap(find.byTooltip('Veranstaltung hinzufügen').at(semesterIndex));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Name *'), name);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'ECTS *'), ects);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Speichern'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Google Play tablet screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── Screenshot 1: Login screen ────────────────────────────────────────────
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('01_login');

    // ── Enter local mode and create a local user ──────────────────────────────
    // Ohne Server-URL startet die App bereits im lokalen Modus.
    final useLocally = find.text('Lokal verwenden (kein Server)');
    if (useLocally.evaluate().isNotEmpty) {
      await tester.tap(useLocally);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    await tester.tap(find.text('Neuen lokalen Benutzer erstellen'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Benutzername *'), 'Studi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erstellen & Anmelden'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ── Plan setup dialog: set plan name, keep 6 semesters ───────────────────
    await tester.enterText(
        find.widgetWithText(TextField, 'Planname'), 'Informatik B.Sc.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan starten'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── Screenshot 2: Main screen with empty plan (6 semesters) ──────────────
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('02_main_empty');

    // ── Add lectures to semester 1 ────────────────────────────────────────────
    await _addLecture(tester, 0, 'Mathematik 1', '8');
    await _addLecture(tester, 0, 'Programmierung 1', '6');
    await _addLecture(tester, 0, 'Technische Informatik', '5');

    // ── Add a lecture to semester 2 ───────────────────────────────────────────
    await _addLecture(tester, 1, 'Analysis', '9');

    // ── Expand semester 1 to show lecture cards ───────────────────────────────
    await tester.tap(find.text('1. Semester'));
    await tester.pumpAndSettle();

    // ── Screenshot 3: Main screen with lectures ───────────────────────────────
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('03_main_with_lectures');
  });
}
