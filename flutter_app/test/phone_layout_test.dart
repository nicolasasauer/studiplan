import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

Lecture _lecture(String name, int ects, {double? grade}) => Lecture(
  id: name,
  name: name,
  ects: ects,
  season: 'both',
  color: '#4ECDC4',
  passed: grade != null,
  grade: grade,
);

Future<StudyPlanProvider> _plan() async {
  SharedPreferences.setMockInitialValues({});
  final p = StudyPlanProvider();
  await p.initialize();
  await p.enterLocalMode();
  await p.initializePlan('Mechatronik B.Sc.', 6, 'winter', targetEcts: 180);
  final s = p.plan.semesters;
  await p.addLecture(_lecture('Höhere Mathematik 1', 8, grade: 2.3), s[0].id);
  await p.addLecture(_lecture('Grundlagen der Elektrotechnik 1', 7), s[0].id);
  await p.addLecture(_lecture('Ethik', 5), null);
  return p;
}

/// Pumps the app at a phone size; layout overflows fail the test.
Future<void> _pumpPhone(
  WidgetTester tester,
  StudyPlanProvider p, {
  Size size = const Size(360, 640),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: p, child: const StudiPlanApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(320, 640), Size(360, 640), Size(412, 915)]) {
    testWidgets('fits a ${size.width.toInt()} dp wide phone', (tester) async {
      final p = await _plan();
      await _pumpPhone(tester, p, size: size);

      // The plan name stays visible next to the icons.
      expect(find.text('Mechatronik B.Sc.'), findsOneWidget);
      expect(
        tester.getSize(find.text('Mechatronik B.Sc.')).width,
        greaterThan(80),
      );
      // Less frequent actions live in the menu.
      expect(find.byKey(const Key('header-menu')), findsOneWidget);
      expect(find.byTooltip('Importieren'), findsNothing);

      // Stat cards stay compact instead of growing to the wrapped height.
      final card = tester.getSize(find.byKey(const Key('stat-planned')));
      expect(card.height, lessThan(150));

      // Expanding a semester and opening the dialogs must not overflow.
      await tester.tap(find.text('1. Semester'));
      await tester.pumpAndSettle();
      expect(find.text('Höhere Mathematik 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Dunkel'), findsOneWidget);
      // Taller than a small screen with big fonts: the dialog scrolls.
      await tester.ensureVisible(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Einstellungen'), findsNothing);
    });
  }

  testWidgets('larger system font on a phone still fits', (tester) async {
    final p = await _plan();
    await _pumpPhone(tester, p, textScale: 1.3);
    await tester.ensureVisible(find.text('1. Semester'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Semester'));
    await tester.pumpAndSettle();
    expect(find.text('Höhere Mathematik 1'), findsOneWidget);

    await tester.tap(find.text('Veranstaltung'));
    await tester.pumpAndSettle();
    expect(find.text('Neue Veranstaltung'), findsOneWidget);
  });

  testWidgets('dragging over the parking lot on a phone fits the hint', (
    tester,
  ) async {
    final p = await _plan();
    await _pumpPhone(tester, p, size: const Size(320, 640));
    await tester.tap(find.byIcon(Icons.close)); // hint banner
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Semester'));
    await tester.pumpAndSettle();
    // Bring the card up from behind the floating button.
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Höhere Mathematik 1')),
    );
    await tester.pump(const Duration(milliseconds: 600)); // long press
    final target = tester.getCenter(find.text('Parkplatz'));
    final from = tester.getCenter(find.text('Höhere Mathematik 1'));
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const ValueKey('drop-hint')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      p.plan.parkingLot.map((l) => l.name),
      contains('Höhere Mathematik 1'),
    );
  });

  testWidgets('the header menu reaches the moved actions', (tester) async {
    final p = await _plan();
    await _pumpPhone(tester, p);
    await tester.tap(find.byKey(const Key('header-menu')));
    await tester.pumpAndSettle();
    for (final label in [
      'Semester hinzufügen',
      'Importieren',
      'Exportieren',
      'Mit Server synchronisieren',
      'Pläne',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Semester hinzufügen'));
    await tester.pumpAndSettle();
    expect(p.plan.semesters, hasLength(7));
  });

  testWidgets('wide windows keep the icon row', (tester) async {
    final p = await _plan();
    await _pumpPhone(tester, p, size: const Size(1200, 800));
    expect(find.byKey(const Key('header-menu')), findsNothing);
    expect(find.byTooltip('Importieren'), findsOneWidget);
  });
}
