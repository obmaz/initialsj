import 'dart:ui';

class VehicleSpec {
  const VehicleSpec({
    required this.id,
    required this.name,
    required this.price,
    required this.accelerationLevel,
    required this.maxSpeedLevel,
    required this.efficiencyLevel,
    required this.idleDrag,
    required this.turnFriction,
    required this.assetName,
    this.garageAssetName,
    this.titleBackgroundAssetName,
    this.tintColorValue = 0xFFFFFFFF,
    this.startsUnlocked = false,
  });

  final String id;
  final String name;
  final int price;
  final int accelerationLevel;
  final int maxSpeedLevel;
  final int efficiencyLevel;
  final double idleDrag;
  final double turnFriction;
  final String assetName;
  final String? garageAssetName;
  final String? titleBackgroundAssetName;
  final int tintColorValue;
  final bool startsUnlocked;

  static double _scaleLevel(int level, double min, double max) {
    final normalized = (level.clamp(1, 10) - 1) / 9;
    return lerpDouble(min, max, normalized)!;
  }

  double get acceleration => _scaleLevel(accelerationLevel, 340, 580);

  double get maxSpeed => maxSpeedLevel.clamp(1, 10) * 40.0;

  double get fuelDrainMultiplier => _scaleLevel(efficiencyLevel, 1.18, 0.72);
}

class VehicleCatalog {
  static const String starterId = 'rx-7';

  static const List<VehicleSpec> vehicles = <VehicleSpec>[
    VehicleSpec(
      id: starterId,
      name: 'RX-7',
      price: 0,
      accelerationLevel: 6,
      maxSpeedLevel: 6,
      efficiencyLevel: 6,
      idleDrag: 160,
      turnFriction: 3.0,
      assetName: 'vehicles/player_rx7_3d.png',
      garageAssetName: 'vehicles/garage_rx7.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_rx7.webp',
      tintColorValue: 0xFFFFFFFF,
      startsUnlocked: true,
    ),
    VehicleSpec(
      id: 'ae86',
      name: 'AE86',
      price: 0,
      accelerationLevel: 7,
      maxSpeedLevel: 7,
      efficiencyLevel: 5,
      idleDrag: 150,
      turnFriction: 2.4,
      assetName: 'vehicles/player_ae86_3d.png',
      garageAssetName: 'vehicles/garage_ae86.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_ae86.webp',
      tintColorValue: 0xFFFFFFFF,
      startsUnlocked: true,
    ),
    VehicleSpec(
      id: 'gr86',
      name: 'GR86',
      price: 350,
      accelerationLevel: 9,
      maxSpeedLevel: 10,
      efficiencyLevel: 4,
      idleDrag: 145,
      turnFriction: 2.7,
      assetName: 'vehicles/player_gr86_3d.png',
      garageAssetName: 'vehicles/garage_gr86.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_gr86.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
    VehicleSpec(
      id: 'lancer',
      name: 'Lancer Evolution',
      price: 500,
      accelerationLevel: 5,
      maxSpeedLevel: 5,
      efficiencyLevel: 10,
      idleDrag: 170,
      turnFriction: 3.2,
      assetName: 'vehicles/player_lancer_3d.png',
      garageAssetName: 'vehicles/garage_lancer.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_lancer.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
    VehicleSpec(
      id: 'porsche-911',
      name: 'Porsche 911',
      price: 700,
      accelerationLevel: 8,
      maxSpeedLevel: 9,
      efficiencyLevel: 6,
      idleDrag: 148,
      turnFriction: 2.2,
      assetName: 'vehicles/player_porsche911_3d.png',
      garageAssetName: 'vehicles/garage_porsche911.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_porsche911.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
    VehicleSpec(
      id: 'model-y',
      name: 'Model Y',
      price: 650,
      accelerationLevel: 8,
      maxSpeedLevel: 7,
      efficiencyLevel: 8,
      idleDrag: 158,
      turnFriction: 2.9,
      assetName: 'vehicles/player_modely_3d.png',
      garageAssetName: 'vehicles/garage_modely.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_modely.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
    VehicleSpec(
      id: 'ioniq-5-n',
      name: 'Ioniq 5 N',
      price: 900,
      accelerationLevel: 10,
      maxSpeedLevel: 8,
      efficiencyLevel: 5,
      idleDrag: 150,
      turnFriction: 2.6,
      assetName: 'vehicles/player_ioniq5n_3d.png',
      garageAssetName: 'vehicles/garage_ioniq5n.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_ioniq5n.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
    VehicleSpec(
      id: 'aventador',
      name: 'Aventador',
      price: 1200,
      accelerationLevel: 9,
      maxSpeedLevel: 10,
      efficiencyLevel: 3,
      idleDrag: 142,
      turnFriction: 2.8,
      assetName: 'vehicles/player_aventador_3d.png',
      garageAssetName: 'vehicles/garage_aventador.webp',
      titleBackgroundAssetName: 'backgrounds/bg_title_aventador.webp',
      tintColorValue: 0xFFFFFFFF,
    ),
  ];

  static VehicleSpec byId(String id) {
    return vehicles.firstWhere(
      (vehicle) => vehicle.id == id,
      orElse: () => vehicles.first,
    );
  }

  static List<String> defaultOwnedVehicleIds() {
    return vehicles
        .where((vehicle) => vehicle.startsUnlocked)
        .map((vehicle) => vehicle.id)
        .toList();
  }
}
