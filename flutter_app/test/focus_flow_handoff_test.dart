import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

Lecture _lecture(String name) => Lecture(
  id: name,
  name: name,
  ects: 5,
  season: 'both',
  color: '#FF6B6B',
);

void main() {
  test('a semester export is a plan holding just that semester', () async {
    SharedPreferences.setMockInitialValues({});
    final p = StudyPlanProvider();
    await p.initialize();
    await p.enterLocalMode();
    await p.initializePlan('Mechatronik B.Sc.', 6, 'winter');
    await p.addLecture(_lecture('Regelungstechnik'), p.plan.semesters[1].id);
    await p.addLecture(_lecture('Ethik'), null);

    final json = p.plan.semesterExportJson(p.plan.semesters[1]);
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['planName'], 'Mechatronik B.Sc.');

    // Read back with StudiPlan's own parser: the layout Focus Flow expects.
    final plan = StudyPlan.fromJson(decoded);
    expect(plan.semesters, hasLength(1));
    expect(plan.semesters.single.number, 2);
    expect(plan.semesters.single.season, 'summer');
    expect(plan.semesters.single.lectures.single.name, 'Regelungstechnik');
    expect(plan.semesters.single.lectures.single.color, '#FF6B6B');
    expect(plan.parkingLot, isEmpty);
  });

  testWidgets('the semester menu copies the semester for Focus Flow', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    SharedPreferences.setMockInitialValues({});
    final p = StudyPlanProvider();
    await p.initialize();
    await p.enterLocalMode();
    await p.initializePlan('Mechatronik B.Sc.', 2, 'winter');
    await p.addLecture(_lecture('Regelungstechnik'), p.plan.semesters[0].id);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: p, child: const StudiPlanApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Weitere Optionen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('An Focus Flow übergeben'));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    final plan = StudyPlan.fromJson(jsonDecode(copied!));
    expect(plan.semesters.single.lectures.single.name, 'Regelungstechnik');
    expect(find.textContaining('1. Semester kopiert'), findsOneWidget);
  });
}
