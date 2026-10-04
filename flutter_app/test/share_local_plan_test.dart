import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';
import 'package:studi_plan/services/api_service.dart';
import 'package:studi_plan/services/storage_service.dart';
import 'package:studi_plan/widgets/share_local_plan_dialog.dart';

import 'support/fake_api.dart';

/// Lokaler Modus mit eingerichtetem Plan "Lokaler Plan".
Future<StudyPlanProvider> _localProvider(
  FakeServer server, [
  FakeApi? api,
]) async {
  SharedPreferences.setMockInitialValues({});
  final provider =
      StudyPlanProvider(apiFactory: (_) => api ?? FakeApi(server));
  await provider.initialize();
  await provider.enterLocalMode();
  await provider.initializePlan('Lokaler Plan', 3, 'winter');
  return provider;
}

Map<String, dynamic> _serverPlan(String name) =>
    StudyPlan(planName: name, isConfigured: true).toJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudyPlanProvider.shareLocalPlan', () {
    test('creates a server account and uploads the local plan', () async {
      final server = FakeServer()..plan = null;
      final provider = await _localProvider(server);

      final result = await provider.shareLocalPlan(
        serverUrl: 'http://server.test/',
        username: 'Neu',
        password: 'geheim123',
        createAccount: true,
      );

      expect(result.status, ShareLocalPlanStatus.shared);
      expect(provider.localMode, isFalse);
      expect(provider.currentUser, 'Neu');
      expect(provider.baseUrl, 'http://server.test');
      expect(provider.plan.planName, 'Lokaler Plan');
      expect(provider.plan.semesters, hasLength(3));
      expect(provider.hasUnsyncedChanges, isFalse);
      expect(server.plan!['planName'], 'Lokaler Plan');
      expect(server.users['Neu'], 'geheim123');

      // Der lokale Plan bleibt im lokalen Modus erhalten.
      final storage = StorageService();
      final ids = await storage.loadLocalPlanIds();
      expect(ids, hasLength(1));
      final local = await storage.loadLocalPlan(ids!.single);
      expect(local!.planName, 'Lokaler Plan');
      expect(local.semesters, hasLength(3));

      // Nach einem Neustart ist die App im Servermodus beim neuen Konto.
      provider.dispose();
      final restarted =
          StudyPlanProvider(apiFactory: (_) => FakeApi(server));
      await restarted.initialize();
      expect(restarted.localMode, isFalse);
      expect(restarted.currentUser, 'Neu');
      expect(restarted.plan.planName, 'Lokaler Plan');
      restarted.dispose();
    });

    test('uploads directly to an existing account without a plan', () async {
      final server = FakeServer()..plan = null;
      final provider = await _localProvider(server);

      final result = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
      );

      expect(result.status, ShareLocalPlanStatus.shared);
      expect(server.plan!['planName'], 'Lokaler Plan');
      provider.dispose();
    });

    test('asks before replacing an existing server plan', () async {
      final server = FakeServer()..plan = _serverPlan('Serverplan');
      final provider = await _localProvider(server);

      final result = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
      );

      expect(result.status, ShareLocalPlanStatus.serverHasPlan);
      expect(provider.localMode, isTrue);
      expect(provider.isLoggedIn, isTrue);
      expect(provider.plan.planName, 'Lokaler Plan');
      expect(server.plan!['planName'], 'Serverplan');
      expect(server.saveCalls, 0);

      final upload = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
        resolution: ServerPlanResolution.uploadLocal,
      );

      expect(upload.status, ShareLocalPlanStatus.shared);
      expect(provider.currentUser, 'Alice');
      expect(server.plan!['planName'], 'Lokaler Plan');
      provider.dispose();
    });

    test('can take over the server plan instead', () async {
      final server = FakeServer()..plan = _serverPlan('Serverplan');
      final provider = await _localProvider(server);

      final result = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
        resolution: ServerPlanResolution.keepServer,
      );

      expect(result.status, ShareLocalPlanStatus.shared);
      expect(provider.localMode, isFalse);
      expect(provider.plan.planName, 'Serverplan');
      expect(provider.hasUnsyncedChanges, isFalse);
      expect(server.saveCalls, 0);
      provider.dispose();
    });

    test('stays local when the password is missing or wrong', () async {
      final server = FakeServer()..users['Bob'] = 'richtig';
      final provider = await _localProvider(server);

      final missing = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Bob',
        createAccount: false,
      );
      expect(missing.status, ShareLocalPlanStatus.requiresPassword);

      final wrong = await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Bob',
        password: 'falsch',
        createAccount: false,
      );
      expect(wrong.status, ShareLocalPlanStatus.failed);

      expect(provider.localMode, isTrue);
      expect(provider.plan.planName, 'Lokaler Plan');
      expect(server.saveCalls, 0);
      provider.dispose();
    });

    test('stays local when the server plan cannot be read', () async {
      final server = FakeServer()..plan = _serverPlan('Serverplan');
      final failing = await _localProvider(server, _FailingGetApi(server));

      final result = await failing.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
      );

      expect(result.status, ShareLocalPlanStatus.failed);
      expect(failing.localMode, isTrue);
      expect(server.plan!['planName'], 'Serverplan');
      failing.dispose();
    });

    test('keeps the plan pending when the upload fails', () async {
      final server = FakeServer()..plan = null;
      final api = _FailingSaveApi(server);
      final offline = await _localProvider(server, api);

      final result = await offline.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
      );

      expect(result.status, ShareLocalPlanStatus.shared);
      expect(offline.localMode, isFalse);
      expect(offline.plan.planName, 'Lokaler Plan');
      expect(offline.hasUnsyncedChanges, isTrue);

      api.saveFails = false;
      await offline.refreshPlanFromServer();
      expect(server.plan!['planName'], 'Lokaler Plan');
      expect(offline.hasUnsyncedChanges, isFalse);

      offline.dispose();
    });

    test('keeps the local plan for later use in local mode', () async {
      final server = FakeServer()..plan = null;
      final provider = await _localProvider(server);
      await provider.shareLocalPlan(
        serverUrl: 'http://server.test',
        username: 'Alice',
        password: FakeServer.alicePassword,
        createAccount: false,
      );
      expect(provider.localMode, isFalse);

      await provider.logout();
      await provider.enterLocalMode();
      expect(provider.isLoggedIn, isTrue);
      expect(provider.localPlans.map((p) => p.name), ['Lokaler Plan']);
      expect(provider.plan.semesters, hasLength(3));
      provider.dispose();
    });
  });

  test('rejects a new server account without a proper password', () async {
    final server = FakeServer()..plan = null;
    final provider = await _localProvider(server);

    final result = await provider.shareLocalPlan(
      serverUrl: 'http://server.test',
      username: 'Neu',
      password: 'kurz',
      createAccount: true,
    );

    expect(result.status, ShareLocalPlanStatus.failed);
    expect(result.error, contains('mindestens 8 Zeichen'));
    expect(server.users.containsKey('Neu'), isFalse);
    expect(provider.localMode, isTrue);
    provider.dispose();
  });

  test('reports a locked account without password', () async {
    final server = FakeServer()..users['Alt'] = null;
    final provider = await _localProvider(server);

    final result = await provider.shareLocalPlan(
      serverUrl: 'http://server.test',
      username: 'Alt',
      createAccount: false,
    );

    expect(result.status, ShareLocalPlanStatus.failed);
    expect(result.error, contains('kein Passwort'));
    expect(provider.localMode, isTrue);
    provider.dispose();
  });

  testWidgets('dialog asks about an existing server plan and uploads',
      (tester) async {
    final server = FakeServer()..plan = _serverPlan('Serverplan');
    late StudyPlanProvider provider;
    await tester.runAsync(() async {
      provider = await _localProvider(server);
    });
    bool? shared;

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        // InkSparkle braucht einen Shader, den es im Testlauf nicht gibt.
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              shared = await showDialog<bool>(
                context: context,
                builder: (_) => const ShareLocalPlanDialog(),
              );
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Server-URL'), 'http://server.test');
    await tester.enterText(
        find.widgetWithText(TextField, 'Benutzername auf dem Server'),
        'Alice');
    await tester.tap(find.text('Bestehendes Konto'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Passwort *'),
        FakeServer.alicePassword);
    await tester.runAsync(() async {
      await tester.tap(find.text('Plan freigeben'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.text('Konto hat schon einen Plan'), findsOneWidget);
    expect(server.plan!['planName'], 'Serverplan');

    await tester.runAsync(() async {
      await tester.tap(find.text('Lokalen Plan hochladen'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(shared, isTrue);
    expect(provider.localMode, isFalse);
    expect(server.plan!['planName'], 'Lokaler Plan');
    provider.dispose();
  });
}

/// Server erreichbar, aber der Abruf des Plans schlägt fehl.
class _FailingGetApi extends FakeApi {
  _FailingGetApi(super.server);

  @override
  Future<ApiResult<Map<String, dynamic>>> getPlan(
    String username,
    String token,
  ) async =>
      const ApiResult(error: 'HTTP 500');
}

/// Anmeldung klappt, Speichern schlägt fehl, bis [saveFails] `false` ist.
class _FailingSaveApi extends FakeApi {
  _FailingSaveApi(super.server);

  bool saveFails = true;

  @override
  Future<ApiResult<void>> savePlan(
    String username,
    String token,
    Map<String, dynamic> plan,
  ) async {
    if (saveFails) return const ApiResult(error: 'offline');
    return super.savePlan(username, token, plan);
  }
}
