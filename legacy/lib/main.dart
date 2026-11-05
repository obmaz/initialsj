import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:initialsj/app/app.dart';
import 'package:initialsj/core/services/local_storage_service.dart';
import 'package:initialsj/game/world/stage_layout.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StageLayout.discoverAssets();

  // Initialize Services
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final appState = AppStateController(storage);

  // Lock orientation to portrait as per contract
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(InitialsjApp(appState: appState));
}
