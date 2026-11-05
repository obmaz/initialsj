import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:initialsj/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:initialsj/core/services/local_storage_service.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Title Screen should navigate to garage', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final appState = AppStateController(storage);

    await tester.pumpWidget(InitialsjApp(appState: appState));

    // Initial state: Title Screen
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(GestureDetector), findsOneWidget);

    // Tap garage button area
    await tester.tap(find.byType(GestureDetector));
    await tester.pump(); // Start navigation
    await tester.pump(const Duration(seconds: 1)); // Wait for transition

    expect(find.text('GARAGE'), findsOneWidget);
    expect(appState.activeRun, isNull);
  });
}
