import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studi_plan/main.dart';
import 'package:studi_plan/models/local_user_account.dart';
import 'package:studi_plan/models/semester.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/providers/study_plan_provider.dart';
import 'package:studi_plan/services/storage_service.dart';

class _DelayedStorageService extends StorageService {
  _DelayedStorageService({
    required this.localMode,
    this.savedUser,
    this.localUsers = const [],
    this.savedPlan,
  });

  final Completer<void> initGate = Completer<void>();
  final bool localMode;
  final Map<String, String>? savedUser;
  final List<LocalUserAccount> localUsers;
  final StudyPlan? savedPlan;

  @override
  Future<String> loadBaseUrl() async {
    await initGate.future;
    return '';
  }

  @override
  Future<bool?> loadLocalMode() async {
    await initGate.future;
    return localMode;
  }

  @override
  Future<Map<String, String>?> loadUser() async {
    await initGate.future;
    return savedUser;
  }

  @override
  Future<StudyPlan?> loadPlan({
    String? username,
    bool local = false,
    bool fallbackToLegacy = true,
  }) async {
    await initGate.future;
    return savedPlan;
  }

  @override
  Future<List<LocalUserAccount>> loadLocalUsers() async {
    await initGate.future;
    return localUsers;
  }
}

void main() {
  testWidgets('waits for initialization before showing the login screen', (
    tester,
  ) async {
    final storage = _DelayedStorageService(
      localMode: true,
      localUsers: const [LocalUserAccount(username: 'Nico')],
    );
    final provider = StudyPlanProvider(storage: storage);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const StudiPlanApp(),
      ),
    );

    unawaited(provider.initialize());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    storage.initGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Lokal anmelden'), findsOneWidget);
    expect(find.text('Nico'), findsOneWidget);

    provider.dispose();
  });

  testWidgets(
    'restores a configured local plan without reopening setup on startup',
    (tester) async {
      final storage = _DelayedStorageService(
        localMode: true,
        savedUser: const {
          'username': 'Nico',
          'token': 'local-session:Nico',
        },
        localUsers: const [LocalUserAccount(username: 'Nico')],
        savedPlan: StudyPlan(
          planName: 'Nico Plan',
          regularSemesters: 6,
          startSeason: 'winter',
          isConfigured: true,
          semesters: [
            Semester(id: 'semester-1', number: 1, season: 'winter'),
          ],
        ),
      );
      final provider = StudyPlanProvider(storage: storage);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const StudiPlanApp(),
        ),
      );

      unawaited(provider.initialize());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      storage.initGate.complete();
      await tester.pumpAndSettle();

      expect(provider.isLoggedIn, isTrue);
      expect(find.text('Nico Plan'), findsOneWidget);
      expect(find.text('Plan einrichten'), findsNothing);

      provider.dispose();
    },
  );

  testWidgets(
    'treats older local plans without isConfigured flag as already configured',
    (tester) async {
      final storage = _DelayedStorageService(
        localMode: true,
        savedUser: const {
          'username': 'Nico',
          'token': 'local-session:Nico',
        },
        localUsers: const [LocalUserAccount(username: 'Nico')],
        savedPlan: StudyPlan.fromJson({
          'planName': 'Altbestand',
          'regularSemesters': 6,
          'startSeason': 'winter',
          'semesters': [
            {
              'id': 'semester-1',
              'number': 1,
              'season': 'winter',
              'lectures': [],
            },
          ],
          'parkingLot': [],
        }),
      );
      final provider = StudyPlanProvider(storage: storage);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const StudiPlanApp(),
        ),
      );

      unawaited(provider.initialize());
      await tester.pump();

      storage.initGate.complete();
      await tester.pumpAndSettle();

      expect(provider.plan.isConfigured, isTrue);
      expect(find.text('Altbestand'), findsOneWidget);
      expect(find.text('Plan einrichten'), findsNothing);

      provider.dispose();
    },
  );
}
