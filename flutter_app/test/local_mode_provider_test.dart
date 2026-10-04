import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/models/lecture.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyPlanProvider local mode', () {
    test('opens an empty plan on first start, without any account', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();
      await provider.initialize();

      expect(provider.localMode, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.localPlans, hasLength(1));
      expect(provider.plan.isEffectivelyConfigured, isFalse);
      provider.dispose();
    });

    test('creates, switches, renames and restores plans', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();
      await provider.initialize();
      await provider.initializePlan('Bachelor', 6, 'winter');
      final bachelor = provider.currentLocalPlanId!;

      final master = await provider.createLocalPlan();
      expect(provider.currentLocalPlanId, master);
      expect(provider.plan.isEffectivelyConfigured, isFalse);
      await provider.initializePlan('Master', 4, 'summer');
      await provider.updateGradeWeighting(true);
      expect(provider.localPlans.map((p) => p.name), ['Bachelor', 'Master']);

      await provider.switchLocalPlan(bachelor);
      expect(provider.plan.planName, 'Bachelor');
      await provider.updatePlanName('Informatik B.Sc.');
      expect(provider.localPlans.map((p) => p.name),
          ['Informatik B.Sc.', 'Master']);

      await provider.switchLocalPlan(master);
      provider.dispose();

      // Nach dem Neustart: beide Pläne, der zuletzt geöffnete ist offen.
      final restarted = StudyPlanProvider();
      await restarted.initialize();
      expect(restarted.localPlans.map((p) => p.name),
          ['Informatik B.Sc.', 'Master']);
      expect(restarted.currentLocalPlanId, master);
      expect(restarted.plan.regularSemesters, 4);
      expect(restarted.plan.startSeason, 'summer');
      expect(restarted.plan.weightAverageGradeByEcts, isTrue);
      restarted.dispose();
    });

    test('deletes plans and never leaves the app without one', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();
      await provider.initialize();
      await provider.initializePlan('A', 2, 'winter');
      final a = provider.currentLocalPlanId!;
      final b = await provider.createLocalPlan();
      await provider.initializePlan('B', 2, 'winter');

      await provider.deleteLocalPlan(b);
      expect(provider.currentLocalPlanId, a);
      expect(provider.plan.planName, 'A');
      expect(provider.localPlans.map((p) => p.id), [a]);

      await provider.deleteLocalPlan(a);
      expect(provider.localPlans, hasLength(1));
      expect(provider.currentLocalPlanId, isNot(a));
      expect(provider.plan.isEffectivelyConfigured, isFalse);
      provider.dispose();

      final restarted = StudyPlanProvider();
      await restarted.initialize();
      expect(restarted.localPlans, hasLength(1));
      restarted.dispose();
    });

    test('imports a plan next to the existing ones', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();
      await provider.initialize();
      await provider.initializePlan('Vorhanden', 2, 'winter');

      final err = await provider.importJson(jsonEncode(
          StudyPlan(planName: 'Importiert', isConfigured: true).toJson()));

      expect(err, isNull);
      expect(provider.plan.planName, 'Importiert');
      expect(provider.localPlans.map((p) => p.name),
          ['Vorhanden', 'Importiert']);
      provider.dispose();
    });

    test('turns former local users into plans', () async {
      final alice = StudyPlan(
          planName: 'Informatik B.Sc.', isConfigured: true, regularSemesters: 7);
      // Mit Standardnamen: der Benutzername wird zum Plannamen.
      final bob = StudyPlan(isConfigured: true);
      final archived = StudyPlan(planName: 'Freigegeben', isConfigured: true);
      SharedPreferences.setMockInitialValues({
        'sp_local_mode': true,
        'sp_user': 'Bob',
        'sp_token': 'local-session:Bob',
        'sp_local_users': jsonEncode([
          {'username': 'Alice', 'passwordHash': 'salt:hash'},
          {'username': 'Bob', 'passwordHash': null},
          {'username': 'Leer', 'passwordHash': null},
        ]),
        'sp_plan_local_${base64Url.encode(utf8.encode('Alice'))}':
            jsonEncode(alice.toJson()),
        'sp_plan_local_${base64Url.encode(utf8.encode('Bob'))}':
            jsonEncode(bob.toJson()),
        'sp_local_archive': jsonEncode([
          {
            'id': 'x',
            'username': 'Alt',
            'archivedAt': '2026-10-01T10:00:00Z',
            'plan': archived.toJson(),
          },
        ]),
      });

      final provider = StudyPlanProvider();
      await provider.initialize();

      expect(provider.isLoggedIn, isTrue);
      expect(provider.localPlans.map((p) => p.name),
          ['Informatik B.Sc.', 'Bob', 'Freigegeben']);
      // Der zuletzt angemeldete Benutzer wird zum geöffneten Plan.
      expect(provider.plan.planName, 'Bob');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sp_local_users'), isNull);
      expect(prefs.getString('sp_local_archive'), isNull);
      expect(prefs.getString('sp_user'), isNull);
      expect(
          prefs.getKeys().where((k) => k.startsWith('sp_plan_local_')), isEmpty);
      provider.dispose();

      // Die Umstellung läuft nur einmal.
      final restarted = StudyPlanProvider();
      await restarted.initialize();
      expect(restarted.localPlans, hasLength(3));
      expect(restarted.plan.planName, 'Bob');
      restarted.dispose();
    });

    test('turns a very old single local plan into a plan', () async {
      final legacyPlan = StudyPlan(
        planName: 'Alter Offline-Plan',
        regularSemesters: 7,
        startSeason: 'summer',
        isConfigured: true,
      );
      SharedPreferences.setMockInitialValues({
        'sp_local_mode': true,
        'sp_plan': jsonEncode(legacyPlan.toJson()),
      });

      final provider = StudyPlanProvider();
      await provider.initialize();

      expect(provider.localPlans.map((p) => p.name), ['Alter Offline-Plan']);
      expect(provider.plan.regularSemesters, 7);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sp_plan'), isNull);
      provider.dispose();
    });

    test('switching from the server opens the local plans', () async {
      SharedPreferences.setMockInitialValues({'sp_local_mode': false});
      final provider = StudyPlanProvider();
      await provider.initialize();
      expect(provider.isLoggedIn, isFalse);

      await provider.enterLocalMode();
      expect(provider.isLoggedIn, isTrue);
      expect(provider.localPlans, hasLength(1));
      provider.dispose();
    });

    test('updates a lecture even when it is moved to another semester', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();

      await provider.initialize();
      await provider.enterLocalMode();
      await provider.initializePlan('Dana Plan', 2, 'winter');
      final firstId = provider.plan.semesters[0].id;
      final secondId = provider.plan.semesters[1].id;

      final original = Lecture(
        id: 'l1',
        name: 'Mathe',
        ects: 5,
        season: 'winter',
        color: '#FF6B6B',
        semesterId: firstId,
      );
      await provider.addLecture(original, firstId);

      await provider.updateLecture(
        original.copyWith(
          name: 'Mathe II',
          semesterId: secondId,
          passed: true,
        ),
      );

      final firstSemester = provider.plan.semesters.firstWhere(
        (semester) => semester.id == firstId,
      );
      final secondSemester = provider.plan.semesters.firstWhere(
        (semester) => semester.id == secondId,
      );

      expect(firstSemester.lectures, isEmpty);
      expect(secondSemester.lectures, hasLength(1));
      expect(secondSemester.lectures.first.name, 'Mathe II');
      expect(secondSemester.lectures.first.passed, isTrue);

      provider.dispose();
    });

    test('can toggle a legacy semester lecture by id even without semester hint', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudyPlanProvider();

      await provider.initialize();
      await provider.enterLocalMode();

      final err = await provider.importJson(jsonEncode({
        'planName': 'Legacy',
        'regularSemesters': 1,
        'startSeason': 'winter',
        'isConfigured': true,
        'semesters': [
          {
            'id': 'semester-1',
            'number': 1,
            'season': 'winter',
            'lectures': [
              {
                'id': 'l1',
                'name': 'Physik',
                'ects': 6,
                'season': 'winter',
                'color': '#45B7D1',
              },
            ],
          },
        ],
        'parkingLot': [],
      }));

      expect(err, isNull);
      expect(provider.plan.semesters.first.lectures.first.semesterId, 'semester-1');

      await provider.toggleLecturePassed('l1', null);

      expect(provider.plan.semesters.first.lectures.first.passed, isTrue);

      provider.dispose();
    });
  });
}
