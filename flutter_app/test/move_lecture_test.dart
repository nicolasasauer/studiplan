import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

Lecture _lecture(String id, {String season = 'both'}) => Lecture(
      id: id,
      name: id,
      ects: 5,
      season: season,
      color: '#4ECDC4',
    );

/// A local plan with three semesters: s1 holds a and b, s2 holds c, the
/// parking lot holds p.
Future<StudyPlanProvider> _provider() async {
  SharedPreferences.setMockInitialValues({});
  final provider = StudyPlanProvider();
  await provider.initialize();
  await provider.enterLocalMode();
  await provider.createUser('Studi', null);
  await provider.initializePlan('Plan', 3, 'winter');
  final s = provider.plan.semesters;
  await provider.addLecture(_lecture('a'), s[0].id);
  await provider.addLecture(_lecture('b'), s[0].id);
  await provider.addLecture(_lecture('c'), s[1].id);
  await provider.addLecture(_lecture('p'), null);
  return provider;
}

List<String> _ids(List<Lecture> lectures) =>
    lectures.map((l) => l.id).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moveLecture', () {
    test('moves between semesters and updates semesterId', () async {
      final p = await _provider();
      final s = p.plan.semesters;

      expect(await p.moveLecture('a', s[1].id), isTrue);

      expect(_ids(s[0].lectures), ['b']);
      expect(_ids(s[1].lectures), ['c', 'a']);
      expect(s[1].lectures.last.semesterId, s[1].id);
      p.dispose();
    });

    test('moves to and from the parking lot', () async {
      final p = await _provider();
      final s = p.plan.semesters;

      expect(await p.moveLecture('a', null), isTrue);
      expect(_ids(p.plan.parkingLot), ['p', 'a']);
      expect(p.plan.parkingLot.last.semesterId, isNull);

      expect(await p.moveLecture('p', s[2].id), isTrue);
      expect(_ids(p.plan.parkingLot), ['a']);
      expect(_ids(s[2].lectures), ['p']);
      expect(s[2].lectures.single.semesterId, s[2].id);
      p.dispose();
    });

    test('dropping where it already is changes nothing', () async {
      final p = await _provider();
      final s = p.plan.semesters;

      expect(await p.moveLecture('a', s[0].id), isFalse);
      expect(_ids(s[0].lectures), ['a', 'b']);
      expect(await p.moveLecture('p', null), isFalse);
      expect(_ids(p.plan.parkingLot), ['p']);
      p.dispose();
    });

    test('an unknown lecture or target changes nothing', () async {
      final p = await _provider();
      final s = p.plan.semesters;

      expect(await p.moveLecture('gone', s[1].id), isFalse);
      expect(await p.moveLecture('a', 'no-such-semester'), isFalse);
      expect(_ids(s[0].lectures), ['a', 'b']);
      expect(_ids(s[1].lectures), ['c']);
      p.dispose();
    });

    test('finds the lecture where it is now, not where a drag began',
        () async {
      final p = await _provider();
      final s = p.plan.semesters;
      // Something (a sync, another dialog) moved it after the drag started.
      await p.moveLecture('a', s[2].id);

      expect(await p.moveLecture('a', s[1].id), isTrue);
      expect(_ids(s[2].lectures), isEmpty);
      expect(_ids(s[1].lectures), ['c', 'a']);
      p.dispose();
    });

    test('index puts it back where it was, clamped to the list', () async {
      final p = await _provider();
      final s = p.plan.semesters;

      await p.moveLecture('a', s[1].id);
      expect(await p.moveLecture('a', s[0].id, index: 0), isTrue);
      expect(_ids(s[0].lectures), ['a', 'b']);

      expect(await p.moveLecture('b', s[1].id, index: 99), isTrue);
      expect(_ids(s[1].lectures), ['c', 'b']);
      expect(await p.moveLecture('b', s[1].id, index: -3), isTrue);
      expect(_ids(s[1].lectures), ['b', 'c']);
      p.dispose();
    });

    test('a move is saved and survives a restart', () async {
      final p = await _provider();
      final target = p.plan.semesters[2].id;
      await p.moveLecture('a', target);
      p.dispose();

      final restarted = StudyPlanProvider();
      await restarted.initialize();
      final sem = restarted.plan.semesters.firstWhere((s) => s.id == target);
      expect(_ids(sem.lectures), ['a']);
      restarted.dispose();
    });

    test('locateLecture reports semester and position', () async {
      final p = await _provider();
      final s = p.plan.semesters;
      expect(p.locateLecture('b'), (semesterId: s[0].id, index: 1));
      expect(p.locateLecture('p'), (semesterId: null, index: 0));
      expect(p.locateLecture('gone'), isNull);
      p.dispose();
    });
  });
}
