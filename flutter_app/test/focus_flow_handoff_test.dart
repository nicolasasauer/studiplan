import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';
import 'package:studi_plan/services/focus_flow_handoff.dart';

Lecture _lecture(String name, {String? examDate}) => Lecture(
  id: name,
  name: name,
  ects: 5,
  season: 'both',
  color: '#FF6B6B',
  examDate: examDate,
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

  test('the link carries the semester in the plan layout', () async {
    SharedPreferences.setMockInitialValues({});
    final p = StudyPlanProvider();
    await p.initialize();
    await p.enterLocalMode();
    await p.initializePlan('Mechatronik B.Sc.', 6, 'winter');
    await p.addLecture(
      _lecture('Regelungstechnik', examDate: '2027-02-12'),
      p.plan.semesters[1].id,
    );
    await p.addLecture(_lecture('Ethik'), p.plan.semesters[1].id);

    final link = FocusFlowHandoff.link(p.plan, p.plan.semesters[1]);
    expect(link.scheme, 'focusflow');
    expect(link.host, 'studiplan');
    final data = link.queryParameters['plan']!;
    expect(data, isNot(contains('=')));
    final plan = StudyPlan.fromJson(jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(data)))));
    expect(plan.planName, 'Mechatronik B.Sc.');
    expect(plan.semesters.single.number, 2);
    // Without a start year there is none in the link.
    final raw = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(data))));
    expect(raw['startSeason'], 'winter');
    expect((raw as Map).containsKey('startYear'), isFalse);
    p.plan.startYear = 2025;
    final withYear = jsonDecode(utf8.decode(base64Url.decode(base64Url
        .normalize(FocusFlowHandoff.link(p.plan, p.plan.semesters[1])
            .queryParameters['plan']!))));
    expect(withYear['startYear'], 2025);

    final lectures = plan.semesters.single.lectures;
    expect(lectures.first.name, 'Regelungstechnik');
    expect(lectures.first.color, '#FF6B6B');
    expect(lectures.first.examDate, '2027-02-12');
    expect(lectures.last.examDate, isNull);
  });

  group('semester menu', () {
    String? copied;
    final opened = <Uri>[];

    final realOpenLink = FocusFlowHandoff.openLink;

    setUp(() {
      copied = null;
      opened.clear();
    });
    tearDown(() => FocusFlowHandoff.openLink = realOpenLink);

    Future<void> handOver(WidgetTester tester) async {
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
    }

    testWidgets('opens Focus Flow with the semester when installed', (
      tester,
    ) async {
      FocusFlowHandoff.openLink = (link) async {
        opened.add(link);
        return true;
      };
      await handOver(tester);

      expect(opened, hasLength(1));
      expect(opened.single.host, 'studiplan');
      expect(copied, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('copies the semester when Focus Flow is missing', (
      tester,
    ) async {
      FocusFlowHandoff.openLink = (link) async {
        opened.add(link);
        return false;
      };
      await handOver(tester);

      expect(opened, hasLength(1));
      expect(copied, isNotNull);
      final plan = StudyPlan.fromJson(jsonDecode(copied!));
      expect(plan.semesters.single.lectures.single.name, 'Regelungstechnik');
      expect(find.textContaining('nicht installiert'), findsOneWidget);
    });
  });

  test('the plan link carries every semester', () async {
    SharedPreferences.setMockInitialValues({});
    final p = StudyPlanProvider();
    await p.initialize();
    await p.enterLocalMode();
    await p.initializePlan('Mechatronik B.Sc.', 3, 'winter');
    await p.addLecture(_lecture('Mathe 1'), p.plan.semesters[0].id);
    await p.addLecture(
      _lecture('Regelungstechnik', examDate: '2027-02-12'),
      p.plan.semesters[1].id,
    );
    await p.addLecture(_lecture('Ethik'), null);

    final link = FocusFlowHandoff.planLink(p.plan);
    final plan = StudyPlan.fromJson(jsonDecode(utf8.decode(
        base64Url.decode(base64Url.normalize(link.queryParameters['plan']!)))));
    expect(plan.semesters.map((s) => s.number), [1, 2, 3]);
    expect(plan.semesters[1].lectures.single.examDate, '2027-02-12');
    // The parking lot is not being studied yet.
    expect(plan.parkingLot, isEmpty);
  });

  group('Focus Flow asks for the plan', () {
    final realOpenLink = FocusFlowHandoff.openLink;
    final opened = <Uri>[];

    setUp(opened.clear);
    tearDown(() => FocusFlowHandoff.openLink = realOpenLink);

    Future<StreamController<Uri>> pump(
      WidgetTester tester,
      StudyPlanProvider p, {
      bool settle = true,
    }) async {
      FocusFlowHandoff.openLink = (link) async {
        opened.add(link);
        return true;
      };
      final links = StreamController<Uri>();
      addTearDown(links.close);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: StudiPlanApp(links: links.stream),
        ),
      );
      // The loading spinner never settles.
      settle ? await tester.pumpAndSettle() : await tester.pump();
      return links;
    }

    testWidgets('answers right away with the open plan', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = StudyPlanProvider();
      await p.initialize();
      await p.enterLocalMode();
      await p.initializePlan('Mechatronik B.Sc.', 2, 'winter');
      await p.addLecture(_lecture('Regelungstechnik'), p.plan.semesters[1].id);
      final links = await pump(tester, p);

      links.add(Uri.parse('https://example.com/export'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);

      links.add(Uri.parse('studiplan://export'));
      await tester.pumpAndSettle();

      expect(opened.single.scheme, 'focusflow');
      expect(opened.single.host, 'studiplan');
      expect(find.text('Plan an Focus Flow gesendet'), findsOneWidget);
    });

    testWidgets('a request during start-up waits for the plan', (
      tester,
    ) async {
      // A plan saved earlier, which the next start loads again.
      SharedPreferences.setMockInitialValues({});
      final before = StudyPlanProvider();
      await before.initialize();
      await before.enterLocalMode();
      await before.initializePlan('Mechatronik B.Sc.', 2, 'winter');
      await before.addLecture(_lecture('Mathe 1'), before.plan.semesters[0].id);

      // Cold start: the link is there before the plan has loaded.
      final p = StudyPlanProvider();
      final links = await pump(tester, p, settle: false);
      links.add(Uri.parse('studiplan://export'));
      await tester.pump();
      expect(opened, isEmpty);

      await tester.runAsync(p.initialize);
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.text('Plan an Focus Flow gesendet'), findsOneWidget);
    });

    testWidgets('a plan without lectures sends nothing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final p = StudyPlanProvider();
      await p.initialize();
      await p.enterLocalMode();
      await p.initializePlan('Mechatronik B.Sc.', 2, 'winter');
      final links = await pump(tester, p);

      links.add(Uri.parse('studiplan://export'));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(find.textContaining('nichts zu senden'), findsOneWidget);
    });
  });
}
