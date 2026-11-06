extends RefCounted
const Hatch = preload("res://scripts/hatch_body.gd")

static func build(car: Node3D) -> void:
	var paint: StandardMaterial3D = car.mat(car.paint,0.4)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.5
	var dark: Material = car.mat(Color("172129"),0.2)
	var glass: Material = car.mat(Color("183546"),0.6)
	if car.model == "wedge": build_wedge(car,paint,dark,glass)
	else: build_muscle(car,paint,dark,glass)
	car.add_headlight(Vector3(0,0.9,-2.0))

static func build_wedge(car: Node3D, paint: Material, dark: Material, glass: Material) -> void:
	car.block(Vector3(0,0.58,0),Vector3(1.58,0.45,4.24),paint)
	Hatch.make_arch_panels(car,paint,dark,1.01,2.12,1.32,0.46,0.40,0.87,0.53)
	car.wedge(Vector3(0,0.65,-1.30),Vector2(1.96,1.60),Vector2(1.82,1.60),0.18,0,paint)
	car.wedge(Vector3(0,0.85,0.10),Vector2(1.76,2.15),Vector2(1.30,1.0),0.36,0.10,glass)
	car.block(Vector3(0,1.23,0.20),Vector3(1.35,0.07,1.03),paint)
	car.block(Vector3(0,0.35,-2.14),Vector3(2.10,0.13,0.19),dark)
	car.block(Vector3(0,0.42,2.15),Vector3(2.10,0.23,0.20),dark)
	for i in range(7):
		car.block(Vector3(0,1.02-i*0.022,0.85+i*0.16),Vector3(1.45,0.055,0.085),dark)
	for side in [-1.0,1.0]:
		Hatch.beam(car,Vector3(side*0.88,0.86,-0.98),Vector3(side*0.66,1.22,-0.30),0.065,paint)
		car.block(Vector3(side*0.91,0.74,0.56),Vector3(0.17,0.20,0.65),dark)
		car.block(Vector3(side*1.02,0.98,-0.52),Vector3(0.23,0.10,0.25),paint)
		car.block(Vector3(side*0.62,0.86,-1.73),Vector3(0.48,0.10,0.42),paint)
		var lamp: Material = car.mat(Color("d5faff"),0,true)
		Hatch.beam(car,Vector3(side*0.83,0.80,-2.17),Vector3(side*0.64,0.73,-2.17),0.045,lamp)
		Hatch.beam(car,Vector3(side*0.64,0.73,-2.17),Vector3(side*0.43,0.80,-2.17),0.045,lamp)
		car.block(Vector3(side*0.64,1.02,1.72),Vector3(0.10,0.48,0.12),dark)
		var red: StandardMaterial3D = car.mat(Color("ff372c"),0,true)
		car.brake_lights.append(red)
		for i in range(3): car.block(Vector3(side*(0.40+i*0.19),0.78,2.14),Vector3(0.15,0.11,0.045),red)
		car.add_boost_jet(Vector3(side*0.55,0.40,2.25),0.18)
	car.block(Vector3(0,0.72,-2.16),Vector3(0.25,0.29,0.06),paint)
	for side in [-1.0,1.0]:
		car.block(Vector3(side*0.61,1.29,1.80),Vector3(0.98,0.07,0.40),paint)
		car.block(Vector3(side*1.07,1.34,1.80),Vector3(0.05,0.16,0.35),dark)
	Hatch.label(car,"VELTRIX",Vector3(0,0.66,2.27),Color("e4e7ea"),0.002)

static func build_muscle(car: Node3D, paint: Material, dark: Material, glass: Material) -> void:
	var cream: Material = car.mat(Color("e8e2c8"),0.2)
	car.block(Vector3(0,0.70,0),Vector3(1.56,0.62,4.24),paint)
	Hatch.make_arch_panels(car,paint,dark,0.98,2.12,1.30,0.48,0.42,1.02,0.60)
	car.block(Vector3(0,1.04,-1.14),Vector3(1.85,0.06,1.89),paint)
	car.wedge(Vector3(0,1.01,0.35),Vector2(1.72,2.30),Vector2(1.40,0.95),0.43,-0.20,glass)
	car.block(Vector3(0,1.46,0.15),Vector3(1.45,0.07,1.0),paint)
	for side in [-1.0,1.0]:
		Hatch.beam(car,Vector3(side*0.86,1.02,-0.80),Vector3(side*0.70,1.45,-0.33),0.09,paint)
		Hatch.beam(car,Vector3(side*0.70,1.45,0.63),Vector3(side*0.86,1.02,1.50),0.14,paint)
		car.block(Vector3(side*0.99,1.08,-0.53),Vector3(0.18,0.13,0.25),dark)
		var red: StandardMaterial3D = car.mat(Color("f03524"),0,true)
		car.brake_lights.append(red)
		for y in [0.80,0.92]: car.block(Vector3(side*0.64,y,2.18),Vector3(0.42,0.06,0.025),red)
		car.block(Vector3(side*0.68,0.90,-2.16),Vector3(0.44,0.36,0.08),dark)
		var lamp := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.14
		mesh.bottom_radius = 0.14
		mesh.height = 0.035
		mesh.radial_segments = 16
		lamp.mesh = mesh
		lamp.material_override = car.mat(Color("ffe5b5"),0,true)
		car.body.add_child(lamp)
		lamp.rotation.x = PI/2
		lamp.position = Vector3(side*0.68,0.89,-2.22)
		car.block(Vector3(side*0.68,1.07,-2.22),Vector3(0.34,0.035,0.025),car.mat(Color("fff3d7"),0,true))
		car.add_boost_jet(Vector3(side*0.73,0.35,2.26),0.23)
	# Offset stripes, divided grille and paired horizontal rear lights identify Ironvale.
	for stripe in [Vector2(-0.28,0.10),Vector2(0.02,0.23)]:
		car.block(Vector3(stripe.x,1.077,-1.15),Vector3(stripe.y,0.015,1.86),cream)
		car.block(Vector3(stripe.x,1.502,0.15),Vector3(stripe.y,0.015,1.0),cream)
		car.block(Vector3(stripe.x,1.025,1.84),Vector3(stripe.y,0.015,0.56),cream)
		car.block(Vector3(stripe.x,0.79,2.17),Vector3(stripe.y,0.38,0.018),cream)
	car.block(Vector3(0,0.64,-2.17),Vector3(2.04,0.12,0.18),car.mat(Color("a5b4bb"),0.8))
	car.block(Vector3(0,0.83,-2.16),Vector3(0.78,0.26,0.035),dark)
	car.block(Vector3(0,0.86,-2.20),Vector3(0.20,0.30,0.04),paint)
	car.block(Vector3(0,0.56,2.17),Vector3(2.04,0.12,0.18),car.mat(Color("a5b4bb"),0.8))
	Hatch.label(car,"IRONVALE",Vector3(0,0.68,2.28),Color("e4e7ea"),0.0018)
