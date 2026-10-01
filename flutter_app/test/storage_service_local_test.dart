import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studi_plan/models/local_user_account.dart';
import 'package:studi_plan/models/study_plan.dart';
import 'package:studi_plan/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService local persistence', () {
    test('round-trips local users and user-scoped local plans', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      await storage.saveLocalUsers(const [
        LocalUserAccount(username: 'Alice', passwordHash: 'salt:hash'),
        LocalUserAccount(username: 'Bob'),
      ]);

      await storage.savePlan(
        StudyPlan(
          planName: 'Alice Plan',
          regularSemesters: 6,
          startSeason: 'winter',
          isConfigured: true,
        ),
        username: 'Alice',
        local: true,
      );

      final users = await storage.loadLocalUsers();
      final plan = await storage.loadPlan(
        username: 'Alice',
        local: true,
        fallbackToLegacy: false,
      );

      expect(users.map((user) => user.username).toList(), ['Alice', 'Bob']);
      expect(users.first.passwordHash, 'salt:hash');
      expect(plan?.planName, 'Alice Plan');
      expect(plan?.isConfigured, isTrue);
    });
  });
}
