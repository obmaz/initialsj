import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:initialsj/app/router/app_router.dart';
import 'package:initialsj/app/theme/app_theme.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';

class InitialsjApp extends StatelessWidget {
  final AppStateController appState;

  const InitialsjApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: appState)],
      child: MaterialApp.router(
        title: 'initialsj',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.retroTheme,
        routerConfig: AppRouter.router,
        builder: (context, child) {
          return _WebMobileViewport(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

class _WebMobileViewport extends StatelessWidget {
  const _WebMobileViewport({required this.child});

  static const double _aspectRatio = 1 / 2;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            var frameWidth = maxWidth;
            var frameHeight = frameWidth / _aspectRatio;

            if (frameHeight > maxHeight) {
              frameHeight = maxHeight;
              frameWidth = frameHeight * _aspectRatio;
            }

            final frameSize = Size(frameWidth, frameHeight);

            return SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: frameSize,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
