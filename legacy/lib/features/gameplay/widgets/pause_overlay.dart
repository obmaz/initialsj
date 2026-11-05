import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:initialsj/app/router/app_router.dart';
import 'package:initialsj/game/engine/game_session_controller.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';
import 'package:initialsj/shared/widgets/retro_button.dart';

class PauseOverlay extends StatelessWidget {
  final GameSessionController sessionController;

  const PauseOverlay({super.key, required this.sessionController});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateController>();

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              RetroButton(
                text: 'RESUME',
                onPressed: () => sessionController.resume(),
              ),
              const SizedBox(height: 12),
              RetroButton(
                text: 'RESTART',
                onPressed: () {
                  appState.startNewRun(appState.activeRun?.stageNumber ?? 1);
                  context.pushReplacement(AppRouter.gameplayPath);
                },
                color: Colors.orange.shade900,
              ),
              const SizedBox(height: 12),
              RetroButton(
                text: 'HOME',
                onPressed: () {
                  appState.endRun();
                  context.go(AppRouter.titlePath);
                },
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
