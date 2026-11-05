import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:initialsj/app/router/app_router.dart';
import 'package:initialsj/shared/models/vehicle_spec.dart';
import 'package:initialsj/shared/state/app_state_controller.dart';

class VehicleSelectScreen extends StatefulWidget {
  const VehicleSelectScreen({super.key});

  @override
  State<VehicleSelectScreen> createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppStateController>();
    final initialIndex = appState.vehicleCatalog.indexWhere(
      (vehicle) => vehicle.id == appState.selectedVehicle.id,
    );
    _pageIndex = initialIndex < 0 ? 0 : initialIndex;
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateController>();
    final vehicles = appState.vehicleCatalog;
    final vehicle = vehicles[_pageIndex.clamp(0, vehicles.length - 1)];
    final isOwned = appState.ownsVehicle(vehicle.id);

    return Scaffold(
      backgroundColor: const Color(0xFF081216),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GARAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'COINS ${appState.profile.coinBalance}',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _pageIndex = index;
                  });
                },
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final item = vehicles[index];
                  final owned = appState.ownsVehicle(item.id);
                  return _VehiclePage(vehicle: item, isOwned: owned);
                },
              ),
            ),
            _PageDots(count: vehicles.length, index: _pageIndex),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _VehicleStatsPanel(
                vehicle: vehicle,
                isOwned: isOwned,
                coinBalance: appState.profile.coinBalance,
                onBuy: () async {
                  await appState.buyVehicle(vehicle.id);
                },
                onStart: isOwned
                    ? () async {
                        if (appState.selectedVehicle.id != vehicle.id) {
                          await appState.selectVehicle(vehicle.id);
                        }
                        appState.startNewRun(1);
                        if (!context.mounted) {
                          return;
                        }
                        context.go(AppRouter.gameplayPath);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePage extends StatelessWidget {
  const _VehiclePage({required this.vehicle, required this.isOwned});

  final VehicleSpec vehicle;
  final bool isOwned;

  @override
  Widget build(BuildContext context) {
    final assetPath =
        'assets/images/${vehicle.garageAssetName ?? vehicle.assetName}';
    final lockedColorFilter = ColorFilter.matrix(<double>[
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: ColorFiltered(
                colorFilter: isOwned
                    ? const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.srcOver,
                      )
                    : lockedColorFilter,
                child: Opacity(
                  opacity: isOwned ? 1 : 0.45,
                  child: Image.asset(assetPath),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleStatsPanel extends StatelessWidget {
  const _VehicleStatsPanel({
    required this.vehicle,
    required this.isOwned,
    required this.coinBalance,
    required this.onBuy,
    required this.onStart,
  });

  final VehicleSpec vehicle;
  final bool isOwned;
  final int coinBalance;
  final Future<void> Function() onBuy;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final canBuy = coinBalance >= vehicle.price;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatBar(label: 'ACCEL', level: vehicle.accelerationLevel),
          const SizedBox(height: 8),
          _StatBar(label: 'MAX SPD', level: vehicle.maxSpeedLevel),
          const SizedBox(height: 8),
          _StatBar(label: 'EFFICIENCY', level: vehicle.efficiencyLevel),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isOwned
                ? FilledButton(onPressed: onStart, child: const Text('START'))
                : FilledButton(
                    onPressed: canBuy
                        ? () async {
                            await onBuy();
                          }
                        : null,
                    child: Text('BUY ${vehicle.price}'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.level});

  final String label;
  final int level;

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(1, 10);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: List.generate(
              10,
              (index) => Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: index == 9 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: index < clampedLevel
                        ? const Color(0xFFFF7043)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '$clampedLevel/10',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (dotIndex) => Container(
          width: dotIndex == index ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: dotIndex == index ? const Color(0xFFFF7043) : Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
