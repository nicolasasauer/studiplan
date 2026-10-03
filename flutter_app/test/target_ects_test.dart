import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

Lecture _lecture(String name, int ects) =>
    Lecture(id: name, name: name, ects: ects, season: 'both', color: '#4ECDC4');

Future<StudyPlanProvider> _plan({int? target}) async {
  SharedPreferences.setMockInitialValues({});
  final p = StudyPlanProvider();
  await p.initialize();
  await p.enterLocalMode();
  await p.createUser('Studi', null);
  await p.initializePlan('Plan', 2, 'winter', targetEcts: target);
  final s = p.plan.semesters;
  await p.addLecture(_lecture('Mathe', 8), s[0].id);
  await p.addLecture(_lecture('Physik', 5), s[1].id);
  await p.addLecture(_lecture('Ethik', 30), null);
  return p;
}

Future<void> _pumpApp(WidgetTester tester, StudyPlanProvider p) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: p, child: const StudiPlanApp()),
  );
  await tester.pumpAndSettle();
}

Finder _inCard(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  group('StudyPlan.targetEcts', () {
    test('plans without the key have no target', () {
      final plan = StudyPlan.fromJson({'planName': 'Alt', 'semesters': []});
      expect(plan.targetEcts, isNull);
      expect(plan.targetDelta, isNull);
      expect(plan.toJson().containsKey('targetEcts'), isFalse);
    });

    test('survives a JSON round trip', () {
      final json = jsonDecode(jsonEncode(StudyPlan(targetEcts: 180).toJson()));
      expect(StudyPlan.fromJson(json).targetEcts, 180);
    });

    test('stored values outside 1..999 or of the wrong type are dropped', () {
      int? read(Object? v) => StudyPlan.fromJson({'targetEcts': v}).targetEcts;
      expect(read(0), isNull);
      expect(read(-30), isNull);
      expect(read('180'), isNull);
      expect(read(double.nan), isNull);
      expect(read(double.infinity), isNull);
      expect(read(180.7), 180);
      expect(read(5000), 999);
    });

    test('parses what the user types', () {
      expect(StudyPlan.parseTargetEcts(''), isNull);
      expect(StudyPlan.parseTargetEcts('  '), isNull);
      expect(StudyPlan.parseTargetEcts(' 210 '), 210);
      for (final bad in ['0', '1000', 'abc', '-5', '1.5']) {
        expect(
          () => StudyPlan.parseTargetEcts(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('the delta counts semesters only, not the parking lot', () async {
      final p = await _plan(target: 20);
      // 8 + 5 planned; the 30 ECTS in the parking lot do not count.
      expect(p.plan.totalEcts, 13);
      expect(p.plan.targetDelta, -7);
      p.dispose();
    });

    test('labels', () {
      expect(targetDeltaLabel(-7), 'noch 7 ECTS offen');
      expect(targetDeltaLabel(0), 'Ziel genau erreicht');
      expect(targetDeltaLabel(3), '3 ECTS über dem Ziel');
    });
  });

  group('provider', () {
    test('settings save the target and it survives a restart', () async {
      final p = await _plan();
      await p.updatePlanSettings(
        weightAverageGradeByEcts: true,
        targetEcts: 180,
      );
      await p.logout();
      p.dispose();

      final restarted = StudyPlanProvider();
      await restarted.initialize();
      expect(await restarted.login('Studi', null), isNull);
      expect(restarted.plan.targetEcts, 180);
      expect(restarted.plan.weightAverageGradeByEcts, isTrue);

      await restarted.updatePlanSettings(
        weightAverageGradeByEcts: true,
        targetEcts: null,
      );
      expect(restarted.plan.targetEcts, isNull);
      restarted.dispose();
    });

    test('import keeps the target from the file', () async {
      final p = await _plan(target: 120);
      final exported = p.exportJson();
      await p.updatePlanSettings(
        weightAverageGradeByEcts: false,
        targetEcts: null,
      );
      expect(await p.importJson(exported), isNull);
      expect(p.plan.targetEcts, 120);
      p.dispose();
    });
  });

  group('stat cards', () {
    testWidgets('without a target nothing changes', (tester) async {
      final p = await _plan();
      await _pumpApp(tester, p);
      expect(_inCard('stat-planned', '13 ECTS'), findsOneWidget);
      expect(_inCard('stat-planned', '2 Semester'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('stat-planned')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('below the target: what is missing', (tester) async {
      final p = await _plan(target: 20);
      await _pumpApp(tester, p);
      expect(_inCard('stat-planned', '13 / 20 ECTS'), findsOneWidget);
      expect(_inCard('stat-planned', 'noch 7 ECTS offen'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('stat-planned')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(13 / 20, 1e-9));
    });

    testWidgets('above the target: how much too much', (tester) async {
      final p = await _plan(target: 10);
      await p.updateLecture(
        p.plan.semesters[0].lectures.first.copyWith(passed: true, grade: 2.0),
      );
      await _pumpApp(tester, p);
      expect(_inCard('stat-planned', '3 ECTS über dem Ziel'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('stat-planned')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, 1.0);
      // Passed share is measured against the degree: 8 of 10.
      expect(_inCard('stat-passed', '80 % vom Studium'), findsOneWidget);
    });

    testWidgets('set in the settings dialog, with validation', (tester) async {
      final p = await _plan();
      await _pumpApp(tester, p);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('target-ects')), '0');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bitte eine Zahl von 1 bis 999 eingeben'),
        findsOneWidget,
      );
      expect(p.plan.targetEcts, isNull);

      await tester.enterText(find.byKey(const Key('target-ects')), '15');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(p.plan.targetEcts, 15);
      expect(_inCard('stat-planned', 'noch 2 ECTS offen'), findsOneWidget);

      // Clearing the field removes the target again.
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('target-ects')), '');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(p.plan.targetEcts, isNull);
      expect(_inCard('stat-planned', '2 Semester'), findsOneWidget);
    });
  });
}
