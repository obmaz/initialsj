import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:initialsj/core/services/local_storage_service.dart';
import 'package:initialsj/shared/models/player_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
  });

  group('LocalStorageService Tests', () {
    test('Should return null if no profile exists', () {
      expect(storage.getProfile(), isNull);
    });

    test('Should save and retrieve profile', () async {
      final profile = PlayerProfile(playerId: 'test-id', displayName: 'Tester');
      await storage.saveProfile(profile);

      final retrieved = storage.getProfile();
      expect(retrieved, isNotNull);
      expect(retrieved!.playerId, 'test-id');
      expect(retrieved.displayName, 'Tester');
    });
  });
}
