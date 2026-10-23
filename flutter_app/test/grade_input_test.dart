import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/grade_scale.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';
import 'package:studi_plan/widgets/add_lecture_dialog.dart';

void main() {
  Future<Lecture?> fill(
    WidgetTester tester, {
    GradeScale scale = GradeScale.germany,
    Lecture? existing,
    required Future<void> Function() steps,
  }) async {
    Lecture? saved;
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddLectureDialog(
          existing: existing,
          semesters: const [],
          gradeScale: scale,
          onSave: (l, _) async => saved = l,
        ),
      ),
    ));
    await steps();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    return saved;
  }

  Finder field(String label) =>
      find.widgetWithText(TextFormField, label);

  testWidgets('half ECTS and a German grade by tap', (tester) async {
    final saved = await fill(tester, steps: () async {
      await tester.enterText(field('Name *'), 'Ethik');
      await tester.enterText(field('ECTS *'), '1,5');
      await tester.tap(find.text('Klausur bestanden'));
      await tester.pumpAndSettle();
      // The German steps, no 2,1.
      expect(find.byKey(const Key('grade-2,3')), findsOneWidget);
      expect(find.byKey(const Key('grade-2,1')), findsNothing);
      await tester.tap(find.byKey(const Key('grade-2,0')));
      await tester.pumpAndSettle();
      expect(find.text('2,0'), findsWidgets);
    });

    expect(saved!.ects, 1.5);
    expect(saved.grade, 2.0);
  });

  testWidgets('a typed grade the scale lacks is refused', (tester) async {
    final saved = await fill(tester,
        scale: GradeScale.austria, steps: () async {
      await tester.enterText(field('Name *'), 'Mathe');
      await tester.enterText(field('ECTS *'), '5');
      await tester.tap(find.text('Klausur bestanden'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('grade-2')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('grade-field')), '2,3');
      await tester.pumpAndSettle();
    });

    expect(saved, isNull);
    expect(find.textContaining('Gibt es in Österreich nicht'), findsOneWidget);
  });

  testWidgets('a grade from the old slider stays valid when editing',
      (tester) async {
    final old = Lecture(
      id: 'l1',
      name: 'Physik',
      ects: 5,
      season: 'both',
      color: '#4ECDC4',
      passed: true,
      grade: 2.1,
    );
    final saved = await fill(tester, existing: old, steps: () async {
      await tester.enterText(field('Name *'), 'Physik 1');
    });

    expect(saved!.name, 'Physik 1');
    expect(saved.grade, 2.1);
  });

  testWidgets('settings: grade scale and start year', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = StudyPlanProvider();
    await p.initialize();
    await p.enterLocalMode();
    await p.initializePlan('Mechatronik', 2, 'winter');
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const StudiPlanApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Planeinstellungen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('start-year')), '2025');
    await tester.tap(find.byKey(const Key('grade-scale')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Österreich').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(p.plan.gradeScale, GradeScale.austria);
    expect(p.plan.startYear, 2025);
    expect(find.text('WS 2025/26'), findsOneWidget);
    expect(find.text('SS 2026'), findsOneWidget);
  });
}
