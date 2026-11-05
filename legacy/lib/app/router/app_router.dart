import 'package:go_router/go_router.dart';
import 'package:initialsj/features/garage/vehicle_select_screen.dart';
import 'package:initialsj/features/gameplay/gameplay_screen.dart';
import 'package:initialsj/features/results/result_screen.dart';
import 'package:initialsj/features/title/title_screen.dart';

class AppRouter {
  static const String titlePath = '/';
  static const String gameplayPath = '/gameplay';
  static const String vehicleSelectPath = '/garage';
  static const String resultPath = '/result';

  static final GoRouter router = GoRouter(
    initialLocation: titlePath,
    routes: [
      GoRoute(
        path: titlePath,
        builder: (context, state) => const TitleScreen(),
      ),
      GoRoute(
        path: vehicleSelectPath,
        builder: (context, state) => const VehicleSelectScreen(),
      ),
      GoRoute(
        path: gameplayPath,
        builder: (context, state) => const GameplayScreen(),
      ),
      GoRoute(
        path: resultPath,
        builder: (context, state) => const ResultScreen(),
      ),
    ],
  );
}
