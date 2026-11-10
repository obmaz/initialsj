extends RefCounted
const Geometry = preload("res://models/shared/vehicle_geometry.gd")

static func build(car: Node3D) -> void:
	var white: StandardMaterial3D = car.mat(car.paint,0.18)
	white.roughness = 0.28
	white.clearcoat_enabled = true
	white.clearcoat = 0.3
	var black: StandardMaterial3D = car.mat(Color("181d20"),0.05)
	black.roughness = 0.65
	var glass: StandardMaterial3D = car.mat(Color("182c3b"),0.55)
	var chrome: StandardMaterial3D = car.mat(Color("9aa5a8"),0.8)
	car.block(Vector3(0,0.70,0),Vector3(1.52,0.62,4.12),white)
	car.block(Vector3(0,0.42,0),Vector3(1.53,0.36,4.12),black)
	Geometry.make_arch_panels(car,white,black)
	car.block(Vector3(0,1.015,-1.30),Vector3(1.64,0.055,1.44),white)
	car.wedge(Vector3(0,1.01,0.4),Vector2(1.68,2.4),Vector2(1.40,1.0),0.48,-0.25,glass)
	car.block(Vector3(0,1.52,0.15),Vector3(1.46,0.065,1.04),white)
	for side in [-1.0,1.0]:
		Geometry.beam(car,Vector3(side*0.84,1.02,-0.80),Vector3(side*0.70,1.49,-0.35),0.075,white)
		Geometry.beam(car,Vector3(side*0.70,1.49,0.65),Vector3(side*0.84,1.02,1.60),0.11,white)
		Geometry.beam(car,Vector3(side*0.84,1.02,0.25),Vector3(side*0.70,1.49,0.25),0.065,black)
		car.block(Vector3(side*0.865,1.0,0.25),Vector3(0.045,0.035,2.90),black)
		car.block(Vector3(side*0.906,0.80,0.48),Vector3(0.012,0.35,0.012),black)
		car.block(Vector3(side*0.92,0.94,0.31),Vector3(0.04,0.045,0.18),black)
		car.block(Vector3(side*0.96,1.10,-0.66),Vector3(0.20,0.12,0.25),black)
		# Fictional tapered lamp pods with a paired-bar signature.
		car.wedge(Vector3(side*0.55,1.01,-1.70),Vector2(0.50,0.44),Vector2(0.38,0.30),0.26,0.02,white)
		car.block(Vector3(side*0.55,1.13,-1.925),Vector3(0.42,0.18,0.035),black)
		for y in [1.09,1.17]:
			car.block(Vector3(side*0.55,y,-1.95),Vector3(0.30,0.035,0.02),car.mat(Color("d4faff"),0,true))
		car.block(Vector3(side*0.69,0.68,-2.195),Vector3(0.28,0.08,0.035),car.mat(Color("d58c30")))
	car.block(Vector3(0,0.56,-2.13),Vector3(1.86,0.23,0.19),black)
	for side in [-1.0,1.0]:
		car.block(Vector3(side*0.45,0.84,-2.12),Vector3(0.60,0.20,0.045),black)
	car.block(Vector3(0,0.82,-2.16),Vector3(0.24,0.24,0.07),white)
	car.block(Vector3(0,0.54,2.14),Vector3(1.86,0.25,0.18),black)
	car.block(Vector3(0,0.86,2.08),Vector3(1.76,0.24,0.075),black)
	car.block(Vector3(0,1.035,1.88),Vector3(1.73,0.055,0.15),black)
	var red: StandardMaterial3D = car.mat(Color("d92b23"),0,true)
	car.brake_lights.append(red)
	for side in [-1.0,1.0]:
		car.block(Vector3(side*0.56,0.87,2.125),Vector3(0.58,0.125,0.035),red)
		car.block(Vector3(side*0.80,0.87,2.15),Vector3(0.10,0.105,0.025),car.mat(Color("d58c30")))
		car.block(Vector3(side*0.32,0.87,2.15),Vector3(0.12,0.105,0.025),car.mat(Color("d9ddd5")))
	car.block(Vector3(0,0.64,2.255),Vector3(0.46,0.17,0.025),car.mat(Color("e7e8db")))
	Geometry.label(car,"NIMORI",Vector3(0,0.64,2.273),Color("26312a"),0.002)
	Geometry.label(car,"N-H",Vector3(-0.52,1.006,2.10),Color("20282b"),0.0015)
	Geometry.beam(car,Vector3(0,1.11,1.48),Vector3(0.37,1.24,1.23),0.025,black)
	var exhaust := MeshInstance3D.new()
	var pipe := TorusMesh.new()
	pipe.inner_radius = 0.065
	pipe.outer_radius = 0.09
	pipe.rings = 12
	pipe.ring_segments = 6
	exhaust.mesh = pipe
	exhaust.material_override = chrome
	car.body.add_child(exhaust)
	exhaust.position = Vector3(-0.61,0.32,2.23)
	exhaust.rotation.x = PI/2
	car.add_boost_jet(Vector3(-0.61,0.32,2.23),0.13)
	car.add_headlight(Vector3(0,1.1,-1.95))
