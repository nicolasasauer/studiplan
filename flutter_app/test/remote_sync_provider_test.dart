import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';

import 'support/fake_api.dart';

Map<String, Object> _remoteSession() => {
      'sp_base_url': 'http://server.test',
      'sp_local_mode': false,
      'sp_user': 'Alice',
      'sp_token': 'token',
    };

Map<String, dynamic> _serverPlan(String name) =>
    StudyPlan(planName: name, isConfigured: true).toJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyPlanProvider remote sync', () {
    test('keeps offline changes instead of overwriting them on refresh',
        () async {
      SharedPreferences.setMockInitialValues(_remoteSession());
      final server = FakeServer()..plan = _serverPlan('Server');
      final provider =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await provider.initialize();
      expect(provider.plan.planName, 'Server');
      expect(provider.hasUnsyncedChanges, isFalse);

      server.online = false;
      await provider.updatePlanName('Offline');
      expect(provider.hasUnsyncedChanges, isTrue);

      await provider.refreshPlanFromServer();
      expect(provider.plan.planName, 'Offline');
      expect(provider.hasUnsyncedChanges, isTrue);

      server.online = true;
      await provider.refreshPlanFromServer();
      expect(provider.plan.planName, 'Offline');
      expect(server.plan!['planName'], 'Offline');
      expect(provider.hasUnsyncedChanges, isFalse);

      provider.dispose();
    });

    test('uploads pending changes after an app restart', () async {
      SharedPreferences.setMockInitialValues(_remoteSession());
      final server = FakeServer()..plan = _serverPlan('Server');
      final provider =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await provider.initialize();

      server.online = false;
      await provider.updatePlanName('Offline');
      provider.dispose();

      server.online = true;
      final restarted =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await restarted.initialize();

      expect(restarted.plan.planName, 'Offline');
      expect(server.plan!['planName'], 'Offline');
      expect(restarted.hasUnsyncedChanges, isFalse);

      restarted.dispose();
    });

    test('ignores a refresh response that is older than a local edit',
        () async {
      SharedPreferences.setMockInitialValues(_remoteSession());
      final server = FakeServer()..plan = _serverPlan('Server');
      final provider =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await provider.initialize();

      final gate = Completer<void>();
      server.getGate = gate;
      final refresh = provider.refreshPlanFromServer();

      await provider.updatePlanName('Neu');
      gate.complete();
      await refresh;

      expect(provider.plan.planName, 'Neu');
      expect(server.plan!['planName'], 'Neu');

      provider.dispose();
    });

    test('takes over remote changes when nothing is pending', () async {
      SharedPreferences.setMockInitialValues(_remoteSession());
      final server = FakeServer()..plan = _serverPlan('Server');
      final provider =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await provider.initialize();

      server.plan = _serverPlan('Anderes Gerät');
      await provider.refreshPlanFromServer();

      expect(provider.plan.planName, 'Anderes Gerät');
      expect(server.saveCalls, 0);

      provider.dispose();
    });
  });

  test('initializePlan creates distinct semester ids on each device',
      () async {
    SharedPreferences.setMockInitialValues({});
    final a = StudyPlanProvider();
    await a.initialize();
    await a.enterLocalMode();
    await a.createUser('A', null);
    await a.initializePlan('Plan', 3, 'winter');

    SharedPreferences.setMockInitialValues({});
    final b = StudyPlanProvider();
    await b.initialize();
    await b.enterLocalMode();
    await b.createUser('B', null);
    await b.initializePlan('Plan', 3, 'winter');

    final idsA = a.plan.semesters.map((s) => s.id).toSet();
    final idsB = b.plan.semesters.map((s) => s.id).toSet();
    expect(idsA, hasLength(3));
    expect(idsA.intersection(idsB), isEmpty);

    a.dispose();
    b.dispose();
  });
}
