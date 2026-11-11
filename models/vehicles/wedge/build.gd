extends RefCounted
const Geometry = preload("res://models/shared/vehicle_geometry.gd")


static func build(car: Node3D) -> void:
	var aero_parts: Array[MeshInstance3D] = []
	var paint: StandardMaterial3D = car.mat(car.paint, 0.4)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.5
	var dark: Material = car.mat(Color("172129"), 0.2)
	var glass: Material = car.mat(Color("183546"), 0.6)
	car.block(Vector3(0, 0.58, 0), Vector3(1.58, 0.45, 4.24), paint)
	Geometry.make_arch_panels(car, paint, dark, 1.01, 2.12, 1.32, 0.46, 0.40, 0.87, 0.53)
	car.wedge(Vector3(0, 0.65, -1.30), Vector2(1.96, 1.60), Vector2(1.82, 1.60), 0.18, 0, paint)
	car.wedge(Vector3(0, 0.85, 0.10), Vector2(1.76, 2.15), Vector2(1.30, 1.0), 0.36, 0.10, glass)
	car.block(Vector3(0, 1.23, 0.20), Vector3(1.35, 0.07, 1.03), paint)
	car.block(Vector3(0, 0.35, -2.14), Vector3(2.10, 0.13, 0.19), dark)
	car.block(Vector3(0, 0.42, 2.15), Vector3(2.10, 0.23, 0.20), dark)
	for i in range(7):
		car.block(Vector3(0, 1.02 - i * 0.022, 0.85 + i * 0.16), Vector3(1.45, 0.055, 0.085), dark)
	for side in [-1.0, 1.0]:
		Geometry.beam(car, Vector3(side * 0.88, 0.86, -0.98), Vector3(side * 0.66, 1.22, -0.30), 0.065, paint)
		car.block(Vector3(side * 0.91, 0.74, 0.56), Vector3(0.17, 0.20, 0.65), dark)
		car.block(Vector3(side * 1.02, 0.98, -0.52), Vector3(0.23, 0.10, 0.25), paint)
		car.block(Vector3(side * 0.62, 0.86, -1.73), Vector3(0.48, 0.10, 0.42), paint)
		var lamp: Material = car.mat(Color("d5faff"), 0, true)
		Geometry.beam(car, Vector3(side * 0.83, 0.80, -2.17), Vector3(side * 0.64, 0.73, -2.17), 0.045, lamp)
		Geometry.beam(car, Vector3(side * 0.64, 0.73, -2.17), Vector3(side * 0.43, 0.80, -2.17), 0.045, lamp)
		car.block(Vector3(side * .64, .95, 1.72), Vector3(.16, .27, .18), dark)
		aero_parts.append(car.block(Vector3(side * .64, 1.16, 1.72), Vector3(.085, .24, .10), dark))
		var red: StandardMaterial3D = car.mat(Color("ff372c"), 0, true)
		car.brake_lights.append(red)
		for i in range(3):
			car.block(Vector3(side * (0.40 + i * 0.19), 0.78, 2.14), Vector3(0.15, 0.11, 0.045), red)
		car.add_boost_jet(Vector3(side * 0.55, 0.40, 2.25), 0.18)
	car.block(Vector3(0, 0.72, -2.16), Vector3(0.25, 0.29, 0.06), paint)
	for side in [-1.0, 1.0]:
		aero_parts.append(car.block(Vector3(side * .61, 1.29, 1.80), Vector3(.98, .09, .40), paint))
		aero_parts.append(car.block(Vector3(side * 1.07, 1.34, 1.80), Vector3(.065, .16, .35), dark))
	car.add_active_aero(aero_parts, Vector3(0, 1.29, 1.72), .17, deg_to_rad(-7))
	Geometry.label(car, "VELTRIX", Vector3(0, 0.66, 2.27), Color("e4e7ea"), 0.002)

	car.add_headlight(Vector3(0, 0.9, -2.0))
