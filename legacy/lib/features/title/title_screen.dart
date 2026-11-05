import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:initialsj/app/router/app_router.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateController>();
    final selectedVehicle = appState.selectedVehicle;
    const fallbackTitleBackground = 'backgrounds/bg_title_ae86.webp';
    final titleAssetPath =
        'assets/images/${selectedVehicle.titleBackgroundAssetName ?? fallbackTitleBackground}';
    const imageAspectRatio = 506 / 1024;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: imageAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: Image.asset(titleAssetPath, fit: BoxFit.cover),
                  ),
                  _buttonHitArea(
                    constraints: constraints,
                    left: 0.12,
                    top: 0.86,
                    width: 0.78,
                    height: 0.10,
                    onTap: () => context.push(AppRouter.vehicleSelectPath),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buttonHitArea({
    required BoxConstraints constraints,
    required double left,
    required double top,
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: left * constraints.maxWidth,
      top: top * constraints.maxHeight,
      width: width * constraints.maxWidth,
      height: height * constraints.maxHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ColoredBox(color: Colors.transparent),
      ),
    );
  }
}
