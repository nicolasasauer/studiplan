import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';
import 'package:studi_plan/widgets/lecture_drag.dart';

Lecture _lecture(String name, {String season = 'both', int ects = 5}) =>
    Lecture(
      id: name,
      name: name,
      ects: ects,
      season: season,
      color: '#4ECDC4',
    );

/// A local plan: semester 1 (WS) holds Mathe and Physik, semester 2 (SS)
/// holds Chemie, the parking lot holds Ethik. [semesters] adds more.
Future<StudyPlanProvider> _plan({int semesters = 3}) async {
  SharedPreferences.setMockInitialValues({});
  final p = StudyPlanProvider();
  await p.initialize();
  await p.enterLocalMode();
  await p.initializePlan('Plan', semesters, 'winter');
  final s = p.plan.semesters;
  await p.addLecture(_lecture('Mathe', season: 'winter', ects: 8), s[0].id);
  await p.addLecture(_lecture('Physik', season: 'winter'), s[0].id);
  await p.addLecture(_lecture('Chemie', season: 'summer'), s[1].id);
  await p.addLecture(_lecture('Ethik'), null);
  return p;
}

List<String> _names(List<Lecture> l) => l.map((x) => x.name).toList();

Future<void> _pumpApp(WidgetTester tester, StudyPlanProvider p,
    {Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: p,
    child: const StudiPlanApp(),
  ));
  await tester.pumpAndSettle();
  // The hint banner sits between header and list; close it.
  final close = find.byIcon(Icons.close);
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _expand(WidgetTester tester, String header) async {
  await tester.tap(find.text(header));
  await tester.pumpAndSettle();
}

/// Drags the card titled [name] to [to] in small steps, like a hand would.
Future<TestGesture> _dragTo(WidgetTester tester, String name, Offset to,
    {bool release = true}) async {
  final from = tester.getCenter(find.text(name));
  final gesture = await tester.startGesture(from);
  await tester.pump();
  const steps = 12;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (release) {
    await gesture.up();
    await tester.pumpAndSettle();
  }
  return gesture;
}

/// The id of the drop zone whose box contains [point], if any.
String? _zoneAt(WidgetTester tester, Offset point) {
  for (final e in find.byType(LectureDropZone).evaluate()) {
    final box = e.renderObject as RenderBox;
    if ((box.localToGlobal(Offset.zero) & box.size).contains(point)) {
      return (e.widget as LectureDropZone).id;
    }
  }
  return null;
}

void main() {
  setUp(() => debugDragWithMouse = true);
  tearDown(() => debugDragWithMouse = null);

  testWidgets('drags a lecture into another semester and undoes it',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('2. Semester')));

    final s = p.plan.semesters;
    expect(_names(s[0].lectures), ['Physik']);
    expect(_names(s[1].lectures), ['Chemie', 'Mathe']);
    expect(s[1].lectures.last.semesterId, s[1].id);
    expect(find.text('Mathe → 2. Semester'), findsOneWidget);

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    // Back at its old place, in front of Physik.
    expect(_names(s[0].lectures), ['Mathe', 'Physik']);
    expect(_names(s[1].lectures), ['Chemie']);
    p.dispose();
  });

  testWidgets('dropping onto its own semester changes nothing',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('1. Semester')));

    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);
    expect(find.textContaining('→'), findsNothing);
    p.dispose();
  });

  testWidgets('dropping outside every section changes nothing',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    // The stat cards at the top are no drop target.
    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('Geplant')));

    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);
    p.dispose();
  });

  testWidgets('parking lot: in and out, and it never counts in the totals',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    expect(find.text('18 ECTS'), findsOneWidget); // 8 + 5 + 5, Ethik excluded
    await _expand(tester, '1. Semester');

    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('Parkplatz')));

    expect(_names(p.plan.parkingLot), ['Ethik', 'Mathe']);
    expect(p.plan.parkingLot.last.semesterId, isNull);
    expect(p.plan.totalEcts, 10);
    expect(find.text('10 ECTS'), findsOneWidget);

    await _expand(tester, 'Parkplatz');
    await _dragTo(tester, 'Ethik', tester.getCenter(find.text('3. Semester')));
    expect(_names(p.plan.parkingLot), ['Mathe']);
    expect(_names(p.plan.semesters[2].lectures), ['Ethik']);
    p.dispose();
  });

  testWidgets('hovering shows where it goes, and warns on a turnus mismatch',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    // A winter lecture over the summer semester: allowed, but flagged.
    final g = await _dragTo(
        tester, 'Mathe', tester.getCenter(find.text('2. Semester')),
        release: false);
    expect(find.text('Ablegen · Turnus passt nicht'), findsOneWidget);

    // Over the winter semester 3 it is fine.
    await g.moveTo(tester.getCenter(find.text('3. Semester')));
    await tester.pump();
    expect(find.text('Hier ablegen'), findsOneWidget);
    expect(find.text('Ablegen · Turnus passt nicht'), findsNothing);

    await g.up();
    await tester.pumpAndSettle();
    expect(_names(p.plan.semesters[2].lectures), ['Mathe']);
    expect(find.byKey(const ValueKey('drop-hint')), findsNothing);
    p.dispose();
  });

  testWidgets('resting on a collapsed semester opens it', (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');
    expect(find.text('Chemie'), findsNothing); // semester 2 is collapsed

    final g = await _dragTo(
        tester, 'Mathe', tester.getCenter(find.text('2. Semester')),
        release: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chemie'), findsNothing); // not yet
    await tester.pump(LectureDropZone.expandDelay);
    await tester.pump();
    expect(find.text('Chemie'), findsOneWidget);

    await g.up();
    await tester.pumpAndSettle();
    p.dispose();
  });

  testWidgets('passing over a collapsed semester does not open it',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    final g = await _dragTo(
        tester, 'Mathe', tester.getCenter(find.text('2. Semester')),
        release: false);
    await tester.pump(const Duration(milliseconds: 200));
    await g.moveTo(tester.getCenter(find.text('Geplant')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chemie'), findsNothing);
    await g.up();
    await tester.pumpAndSettle();
    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);
    p.dispose();
  });

  testWidgets('a lecture deleted during the drag is not resurrected',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    final g = await _dragTo(
        tester, 'Mathe', tester.getCenter(find.text('2. Semester')),
        release: false);
    // E.g. a sync from another device removed it meanwhile.
    await p.removeLecture('Mathe', p.plan.semesters[0].id);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(_names(p.plan.semesters[1].lectures), ['Chemie']);
    expect(p.locateLecture('Mathe'), isNull);
    expect(tester.takeException(), isNull);
    p.dispose();
  });

  testWidgets('a second finger lifting elsewhere does not drop',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    final g = await _dragTo(
        tester, 'Mathe', tester.getCenter(find.text('2. Semester')),
        release: false);
    final second = await tester.startGesture(const Offset(600, 850),
        pointer: 7);
    await second.up();
    await tester.pump();
    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);

    // The dragging finger still decides.
    await g.moveTo(tester.getCenter(find.text('3. Semester')));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(_names(p.plan.semesters[2].lectures), ['Mathe']);
    p.dispose();
  });

  testWidgets('undo after the old semester was deleted parks the lecture',
      (tester) async {
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('3. Semester')));
    await p.removeSemester(p.plan.semesters[0].id);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(p.plan.parkingLot.map((l) => l.name), contains('Mathe'));
    expect(p.locateLecture('Mathe')!.semesterId, isNull);
    p.dispose();
  });

  testWidgets('on touch screens a quick swipe scrolls, a long press drags',
      (tester) async {
    debugDragWithMouse = false;
    final p = await _plan();
    await _pumpApp(tester, p);
    await _expand(tester, '1. Semester');

    // Quick swipe: no drag.
    await _dragTo(tester, 'Mathe', tester.getCenter(find.text('2. Semester')));
    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);

    // Long press, then move.
    final from = tester.getCenter(find.text('Mathe'));
    final g = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final to = tester.getCenter(find.text('3. Semester'));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(_names(p.plan.semesters[2].lectures), ['Mathe']);
    p.dispose();
  });

  testWidgets(
      'the list scrolls at the edge, and the drop lands where the finger '
      'rests after scrolling', (tester) async {
    final p = await _plan(semesters: 14);
    await _pumpApp(tester, p, size: const Size(900, 600));
    await _expand(tester, '1. Semester');
    final list = find.byType(Scrollable).first;
    expect(find.text('14. Semester'), findsNothing);

    // Hold the card at the bottom edge of the list.
    final bottom = tester.getBottomLeft(list) + const Offset(300, -8);
    final g = await _dragTo(tester, 'Mathe', bottom, release: false);
    final zoneBefore = _zoneAt(tester, bottom);
    final before = tester.state<ScrollableState>(list).position.pixels;
    // About 350 px: well into the list, not yet at its end.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final after = tester.state<ScrollableState>(list).position.pixels;
    expect(after, greaterThan(before));

    // Without moving the finger: whatever is under it now gets the drop,
    // not the section it rested on before the list scrolled.
    final semesterUnderFinger = _zoneAt(tester, bottom);
    expect(semesterUnderFinger, isNotNull);
    expect(semesterUnderFinger, isNot(zoneBefore));
    expect(semesterUnderFinger, isNot(p.plan.semesters[0].id));

    await g.up();
    await tester.pumpAndSettle();
    final target =
        p.plan.semesters.firstWhere((s) => s.id == semesterUnderFinger);
    expect(_names(target.lectures), contains('Mathe'));
    expect(_names(p.plan.semesters[0].lectures), ['Physik']);
    p.dispose();
  });

  testWidgets('scrolled to the very end, releasing over the gap drops nothing',
      (tester) async {
    final p = await _plan(semesters: 14);
    await _pumpApp(tester, p, size: const Size(900, 600));
    await _expand(tester, '1. Semester');
    final list = find.byType(Scrollable).first;

    final bottom = tester.getBottomLeft(list) + const Offset(300, -8);
    final g = await _dragTo(tester, 'Mathe', bottom, release: false);
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final position = tester.state<ScrollableState>(list).position;
    expect(position.pixels, position.maxScrollExtent);

    // Under the finger is the empty space below the last semester.
    expect(find.byKey(const ValueKey('drop-hint')), findsNothing);
    await g.up();
    await tester.pumpAndSettle();
    expect(_names(p.plan.semesters[0].lectures), ['Mathe', 'Physik']);
    p.dispose();
  });
}
