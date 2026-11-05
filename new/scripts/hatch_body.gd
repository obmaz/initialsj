extends RefCounted
# Original low-poly three-door Nimori body; shares the existing driving/effects rig.
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
	make_arch_panels(car,white,black)
	car.block(Vector3(0,1.015,-1.30),Vector3(1.64,0.055,1.44),white)
	car.wedge(Vector3(0,1.01,0.4),Vector2(1.68,2.4),Vector2(1.40,1.0),0.48,-0.25,glass)
	car.block(Vector3(0,1.52,0.15),Vector3(1.46,0.065,1.04),white)
	for side in [-1.0,1.0]:
		beam(car,Vector3(side*0.84,1.02,-0.80),Vector3(side*0.70,1.49,-0.35),0.075,white)
		beam(car,Vector3(side*0.70,1.49,0.65),Vector3(side*0.84,1.02,1.60),0.11,white)
		beam(car,Vector3(side*0.84,1.02,0.25),Vector3(side*0.70,1.49,0.25),0.065,black)
		car.block(Vector3(side*0.865,1.0,0.25),Vector3(0.045,0.035,2.90),black)
		car.block(Vector3(side*0.906,0.80,0.48),Vector3(0.012,0.35,0.012),black)
		car.block(Vector3(side*0.92,0.94,0.31),Vector3(0.04,0.045,0.18),black)
		car.block(Vector3(side*0.96,1.10,-0.66),Vector3(0.20,0.12,0.25),black)
		# Raised rectangular headlamps and their white pop-up covers.
		car.block(Vector3(side*0.55,1.12,-1.70),Vector3(0.43,0.22,0.42),white)
		car.block(Vector3(side*0.55,1.12,-1.918),Vector3(0.40,0.19,0.035),black)
		car.block(Vector3(side*0.55,1.12,-1.94),Vector3(0.32,0.135,0.02),car.mat(Color("fff0cc"),0,true))
		car.block(Vector3(side*0.69,0.68,-2.195),Vector3(0.28,0.08,0.035),car.mat(Color("d58c30")))
	car.block(Vector3(0,0.56,-2.13),Vector3(1.86,0.23,0.19),black)
	car.block(Vector3(0,0.86,-2.09),Vector3(1.65,0.17,0.045),black)
	for y in [0.83,0.88]: car.block(Vector3(0,y,-2.12),Vector3(1.48,0.012,0.025),chrome)
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
	label(car,"NIMORI",Vector3(0,0.64,2.273),Color("26312a"),0.002)
	label(car,"N-H",Vector3(-0.52,1.006,2.10),Color("20282b"),0.0015)
	beam(car,Vector3(0,1.11,1.48),Vector3(0.37,1.24,1.23),0.025,black)
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

static func beam(car: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var part: MeshInstance3D = car.block((a+b)/2,Vector3(width,width,a.distance_to(b)),material)
	part.basis = Basis.looking_at((b-a).normalized(),Vector3.UP)

static func label(car: Node3D, text: String, position: Vector3, color: Color, pixel_size: float) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = 40
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.body.add_child(node)

static func arch_bottom(z: float, axle: float = 1.25, radius: float = 0.46, center_y: float = 0.39) -> float:
	var offset := minf(absf(z-axle),absf(z+axle))
	return center_y+sqrt(maxf(0,radius*radius-offset*offset)) if offset < radius else 0.22

static func make_arch_panels(car: Node3D, white: Material, black: Material, half_width: float = 0.90, half_length: float = 2.06, axle: float = 1.25, radius: float = 0.46, center_y: float = 0.39, upper: float = 1.0, split: float = 0.60) -> void:
	for lower in [false,true]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			for i in range(100):
				var a := -half_length+i*half_length*2/100
				var b := -half_length+(i+1)*half_length*2/100
				var bottom_a := arch_bottom(a,axle,radius,center_y)
				var bottom_b := arch_bottom(b,axle,radius,center_y)
				var top := split if lower else upper
				bottom_a = minf(top,bottom_a) if lower else maxf(split,bottom_a)
				bottom_b = minf(top,bottom_b) if lower else maxf(split,bottom_b)
				var points := [Vector3(side*half_width,bottom_a,a),Vector3(side*half_width,bottom_b,b),Vector3(side*half_width,top,a),Vector3(side*half_width,top,b)]
				for index in ([0,1,2,1,3,2] if side > 0 else [0,2,1,1,2,3]):
					surface.set_normal(Vector3(side,0,0))
					surface.add_vertex(points[index])
		var panel := MeshInstance3D.new()
		panel.mesh = surface.commit()
		panel.material_override = black if lower else white
		car.body.add_child(panel)
