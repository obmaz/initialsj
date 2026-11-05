extends Node3D
const Library = preload("res://scripts/route_library.gd")
const GRASS = preload("res://assets/environment/lakeside-grass.png")
var track: Node3D
var theme := "hawaii"
var rng := RandomNumberGenerator.new()
var batches: Array[MultiMeshInstance3D] = []
var rotating: Array[Node3D] = []
var tree_positions: Array[Vector3] = []
var ground_nodes: Array[MeshInstance3D] = []
var water: MeshInstance3D

func mat(color: Color, metal: float = 0, glow: float = 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.75 if metal == 0 else 0.3
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func transform_at(d: float, lane: float, height: float, size: Vector3, angle: float = 0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, track.heading(d) + angle).scaled_local(size),terrain_point(d,lane) + Vector3.UP * height)

func batch(mesh: Mesh, material: Material, poses: Array[Transform3D], shadows: bool = true) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches.append(node)
	return node

func boxes(material: Material, poses: Array[Transform3D], shadows: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	batch(mesh,material,poses,shadows)

func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d,lane)
	var road_y: float = track.point(d).y
	if theme in ["hawaii", "jeju"] and lane < -(track.half_width(d)+1):
		p.y = lerpf(0.12,road_y - 0.3,clampf((lane+track.half_width(d)+10)/9,0,1))
	else:
		var rise := pow(clampf((absf(lane) - 18) / 140,0,1),1.5)
		p.y = road_y - 0.3 + rise * (10 if theme in ["desert","pyramid"] else 5) * sin(d * 0.012 + lane * 0.035)
	return p

func _ready() -> void:
	theme = Library.theme(track.stage,track.route_node)
	rng.seed = 2006 + track.stage * 31 + track.route_node * 17
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://shaders/biome_ground.gdshader")
	ground.set_shader_parameter("grain",GRASS)
	ground.set_shader_parameter("ground_color",Color(Library.PALETTES[theme]))
	ground.set_shader_parameter("grassness",0.0 if theme in ["desert","pyramid","ruins"] else 1.0)
	if theme in ["hawaii","jeju"]:
		var beach := ground.duplicate()
		beach.set_shader_parameter("ground_color",Color("dccb9c"))
		beach.set_shader_parameter("grassness",0.0)
		ground_band(-19,-10,beach)
	else:
		ground_band(-180,-10,ground)
	ground_band(10,180,ground)
	if theme in ["hawaii","jeju"]:
		make_water()
	match theme:
		"city", "seoul", "ruins": make_city()
		"desert", "pyramid": make_desert()
		"hawaii", "jeju", "amusement": make_trees()
	if theme == "amusement": make_park()
	if theme == "jeju": make_jeju()
	if theme == "seoul": make_seoul()
	make_cover()

func ground_lane(d: float, lane: float) -> float:
	return lane+signf(lane)*(track.half_width(d)-9) if absf(lane) <= 19 else lane

func ground_band(left: float, right: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 200
	for i in range(segments):
		var a: float = track.length * i / segments
		var b: float = track.length * (i + 1) / segments
		var points := [terrain_point(a,ground_lane(a,left)),terrain_point(a,ground_lane(a,right)),terrain_point(b,ground_lane(b,left)),terrain_point(b,ground_lane(b,right))]
		for index in [0,2,1,1,2,3]: surface.add_vertex(points[index])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = material
	add_child(node)
	ground_nodes.append(node)

func set_ground_enabled(enabled: bool) -> void:
	for node in ground_nodes: node.visible = enabled
	if water != null: water.visible = enabled

func make_water() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(180):
		var a: float = track.length * i / 180
		var b: float = track.length * (i + 1) / 180
		var points := [track.point(a,-900),track.point(a,ground_lane(a,-19)),track.point(b,-900),track.point(b,ground_lane(b,-19))]
		for index in [0,2,1,1,2,3]:
			var p: Vector3 = points[index]
			p.y = 0
			surface.set_normal(Vector3.UP)
			surface.add_vertex(p)
	water = MeshInstance3D.new()
	water.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/coastal_water.gdshader")
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func make_trees() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for i in range(100):
		var start := 230.0 if track.entry_side != 0 else 40.0
		var d: float = start + i*(track.length-start-40)/100 + rng.randf_range(-5,5)
		var side := -1.0 if i % 3 == 0 else 1.0
		var lane := side * rng.randf_range(15,55)
		var height := rng.randf_range(9,16)
		trunks.append(transform_at(d,lane,height / 2,Vector3(0.65,height,0.65)))
		crowns.append(transform_at(d,lane,height,Vector3.ONE * rng.randf_range(0.8,1.3),rng.randf_range(0,TAU)))
		tree_positions.append(terrain_point(d,lane))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.5
	trunk_mesh.height = 1
	trunk_mesh.radial_segments = 7
	batch(trunk_mesh,mat(Color("75604a")),trunks)
	if theme == "hawaii":
		var leaf := SurfaceTool.new()
		leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
		for direction in range(8):
			var forward := Vector3(cos(direction * TAU / 8),0,sin(direction * TAU / 8))
			var across := Vector3(-forward.z,0,forward.x)
			for i in range(5):
				var t := i / 5.0
				var u := (i + 1) / 5.0
				var a := forward * t * 5 + Vector3.UP * (sin(t * PI) - t * 2)
				var b := forward * u * 5 + Vector3.UP * (sin(u * PI) - u * 2)
				var points := [a - across * (1-t) * 0.65,a + across * (1-t) * 0.65,b - across * (1-u) * 0.65,b + across * (1-u) * 0.65]
				for index in [0,2,1,1,2,3]: leaf.add_vertex(points[index])
		leaf.generate_normals()
		var material := mat(Color("27834c"))
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		batch(leaf.commit(),material,crowns)
	else:
		var crown := SphereMesh.new()
		crown.radius = 3.5
		crown.height = 6
		crown.radial_segments = 9
		crown.rings = 5
		batch(crown,mat(Color("3f8248")),crowns)

func make_city() -> void:
	var groups: Array[Dictionary] = []
	for i in range(6): groups.append({"poses":[],"dimensions":[]})
	var plinths: Array[Transform3D] = []
	var roof_details: Array[Transform3D] = []
	var rubble: Array[Transform3D] = []
	var count := int(track.length/42)
	for i in range(count):
		var d: float = 250+i*(track.length-430)/count
		var side := -1.0 if i%2 == 0 else 1.0
		if theme == "seoul" and side > 0 and d > 450 and d < 1050: continue
		if track.entry_side != 0 and d < 600: side = float(track.entry_side)
		var lane: float = side*(track.half_width(d)+rng.randf_range(18,56))
		var style: int = (i*5+track.route_node)%6
		var height: float = rng.randf_range(10,23) if style in [0,5] else rng.randf_range(35,95)
		if style == 4: height = rng.randf_range(20,38)
		if theme == "ruins": height *= 0.65
		var width := rng.randf_range(12,24)
		var depth := rng.randf_range(14,32)
		var variant := rng.randf()
		var tiers := 3 if style == 2 else 1
		var base := 0.0
		for tier in range(tiers):
			var h := height*(0.50 if tier == 0 else 0.25) if tiers > 1 else height
			var scale_x := 1.0-tier*0.22
			var size := Vector3(width*scale_x,h,depth*scale_x)
			groups[style].poses.append(transform_at(d,lane,base+h/2,size))
			groups[style].dimensions.append(Color(size.x,size.y,size.z,variant))
			base += h
		plinths.append(transform_at(d,lane,1,Vector3(width*1.1,2,depth*1.1)))
		if style in [0,1,4]:
			roof_details.append(transform_at(d,lane,height+1.2,Vector3(width*0.32,2.4,depth*0.25)))
		if style == 5:
			roof_details.append(transform_at(d-side*2,lane-side*depth*0.3,height*0.62,Vector3(width*1.05,0.35,depth*0.4)))
		if theme == "ruins":
			for piece in range(3): rubble.append(transform_at(d+piece*4,lane-side*5,2+piece*2,Vector3(width*0.6,2,3),rng.randf_range(-0.5,0.5)))
	for style in range(6):
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		var mesh: Mesh
		if style == 3:
			var tower := CylinderMesh.new()
			tower.top_radius = 0.5
			tower.bottom_radius = 0.5
			tower.height = 1
			tower.radial_segments = 16
			mesh = tower
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			mesh = cube
		multi.mesh = mesh
		multi.instance_count = groups[style].poses.size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i,groups[style].poses[i])
			multi.set_instance_custom_data(i,groups[style].dimensions[i])
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/building_facade.gdshader")
		material.set_shader_parameter("ruined",theme == "ruins")
		material.set_shader_parameter("facade_style",style)
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = material
		add_child(node)
		batches.append(node)
	boxes(mat(Color("5d666b")),plinths)
	boxes(mat(Color("78868a"),0.3),roof_details)
	if not rubble.is_empty(): boxes(mat(Color("6d695a")),rubble)

func make_desert() -> void:
	var dunes: Array[Transform3D] = []
	for i in range(40):
		var d: float = 220 + i*(track.length-240)/40
		var side := -1.0 if i % 2 == 0 else 1.0
		if track.entry_side != 0 and d < 600: side = float(track.entry_side)
		dunes.append(transform_at(d,side * rng.randf_range(45,160),-6,Vector3(rng.randf_range(35,65),rng.randf_range(15,35),rng.randf_range(40,80))))
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 14
	sphere.rings = 7
	batch(sphere,mat(Color("d6aa68")),dunes)
	if theme == "pyramid":
		var pyramids: Array[Transform3D] = []
		for i in range(4):
			var side := -1 if i % 2 == 0 else 1
			if i == 0 and track.entry_side != 0: side = track.entry_side
			pyramids.append(transform_at(250+i*350,side*(85+i*12),22,Vector3(70,44,70),PI/4))
		var pyramid := CylinderMesh.new()
		pyramid.top_radius = 0
		pyramid.bottom_radius = 0.5
		pyramid.height = 1
		pyramid.radial_segments = 4
		batch(pyramid,mat(Color("d8bd83")),pyramids)

func make_jeju() -> void:
	var rocks: Array[Transform3D] = []
	for i in range(65): rocks.append(transform_at(230 + i * 20,(-1 if i % 3 == 0 else 1) * rng.randf_range(14,40),1.2,Vector3(rng.randf_range(2,5),rng.randf_range(2,4),rng.randf_range(2,6)),rng.randf_range(0,TAU)))
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1
	rock.radial_segments = 6
	rock.rings = 3
	batch(rock,mat(Color("343d40")),rocks)
	for d in [430.0,1150.0]:
		var rotor := Node3D.new()
		add_child(rotor)
		rotor.position = terrain_point(d,75) + Vector3.UP * 34
		rotor.rotation.y = track.heading(d)
		var tower = track.box(self,terrain_point(d,75) + Vector3.UP * 17,Vector3(1.5,34,1.5),mat(Color("dbe4df")))
		tower.rotation.y = track.heading(d)
		for blade in range(3):
			var arm = track.box(rotor,Vector3.ZERO,Vector3(0.7,13,0.3),mat(Color("e7efed")))
			arm.rotation.z = blade * TAU / 3
			arm.position = Vector3(-sin(arm.rotation.z),cos(arm.rotation.z),0) * 6.5
		rotating.append(rotor)

func make_seoul() -> void:
	var p := terrain_point(950,60)
	var hill := SphereMesh.new()
	hill.radius = 0.5
	hill.height = 1
	hill.radial_segments = 14
	hill.rings = 8
	var hill_poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3(90,36,90)),p+Vector3.UP*8)]
	batch(hill,mat(Color("4e7250")),hill_poses)
	p += Vector3.UP*26
	track.box(self,p + Vector3.UP * 50,Vector3(4,100,4),mat(Color("cbd5df"),0.4))
	var deck := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 11
	mesh.bottom_radius = 8
	mesh.height = 8
	mesh.radial_segments = 12
	deck.mesh = mesh
	deck.material_override = mat(Color("657f95"),0.5)
	add_child(deck)
	deck.position = p + Vector3.UP * 100
	track.box(self,p + Vector3.UP * 119,Vector3(1,30,1),mat(Color("e9e3dd")))

func make_park() -> void:
	var wheel := Node3D.new()
	add_child(wheel)
	wheel.position = terrain_point(650,70) + Vector3.UP * 25
	wheel.rotation.y = track.heading(650)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 17.5
	torus.outer_radius = 18
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = mat(Color("f5e9cf"),0.4)
	wheel.add_child(ring)
	ring.rotation.x = PI / 2
	for i in range(10):
		var angle := i * TAU / 10
		var spoke = track.box(wheel,Vector3(sin(angle),cos(angle),0) * 9,Vector3(0.2,18,0.2),mat(Color("c4d5e0"),0.4))
		spoke.rotation.z = -angle
		track.box(wheel,Vector3(sin(angle),cos(angle),0) * 18,Vector3(3,3,2),mat(Color.from_hsv(i / 10.0,0.7,0.9)))
	rotating.append(wheel)
	var supports: Array[Transform3D] = []
	supports.append(transform_at(650,70,11,Vector3(1.2,25,1.2),0.2))
	boxes(mat(Color("c9d6df")),supports)
	var tents: Array[Transform3D] = []
	for i in range(8): tents.append(transform_at(250 + i * 100,-35,5,Vector3(12,10,12)))
	var roof := CylinderMesh.new()
	roof.top_radius = 0
	roof.bottom_radius = 0.5
	roof.height = 1
	roof.radial_segments = 8
	batch(roof,mat(Color("df5b87")),tents)

func make_cover() -> void:
	var canopy := Library.canopy_span(track.stage,track.route_node)
	if canopy.y > canopy.x: make_canopy(canopy)
	var tunnel := Library.tunnel_span(track.stage,track.route_node)
	if tunnel.y > tunnel.x: make_tunnel(tunnel)

func make_canopy(span: Vector2) -> void:
	var pillars: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	for i in range(int(ceil((span.y-span.x)/16))):
		var d := span.x+8+i*16
		var f: Vector3 = (track.point(d+2)-track.point(d)).normalized()
		var basis := Basis(Vector3.UP,track.heading(d)).rotated(Vector3(-f.z,0,f.x).normalized(),asin(f.y))
		var w: float = track.half_width(d)+2.5
		for side in [-1,1]: pillars.append(Transform3D(basis.scaled_local(Vector3(0.24,6.8,0.24)),track.point(d,side*w)+Vector3.UP*3.4))
		glass.append(Transform3D(basis.scaled_local(Vector3(w*2,0.08,17)),track.point(d)+Vector3.UP*6.8))
		frames.append(Transform3D(basis.scaled_local(Vector3(w*2,0.15,0.25)),track.point(d)+Vector3.UP*6.75))
	boxes(mat(Color("a8c0cf"),0.6),pillars)
	boxes(mat(Color("b7d7df"),0.6),frames)
	var transparent := mat(Color(0.35,0.73,0.83,0.23),0.25)
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.cull_mode = BaseMaterial3D.CULL_DISABLED
	boxes(transparent,glass,false)

func tunnel_profile(d: float) -> Array[Vector3]:
	var w: float = track.half_width(d)+2.4
	var points: Array[Vector3] = [track.point(d,-w)]
	for i in range(17):
		var a := PI*i/16
		points.append(track.point(d,-cos(a)*w)+Vector3.UP*(3.2+sin(a)*5))
	points.append(track.point(d,w))
	return points

func make_tunnel(span: Vector2) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := int(ceil((span.y-span.x)/8))
	for i in range(segments):
		var a := tunnel_profile(lerpf(span.x,span.y,float(i)/segments))
		var b := tunnel_profile(lerpf(span.x,span.y,float(i+1)/segments))
		for j in range(a.size()-1):
			var corners := [a[j],b[j],a[j+1],b[j+1]]
			for index in [0,1,2,1,3,2]: surface.add_vertex(corners[index])
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.mesh = surface.commit()
	var material := mat(Color("37434c") if theme in ["city","seoul"] else Color("635e55"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = material
	add_child(shell)
	var lamps: Array[Transform3D] = []
	for i in range(int((span.y-span.x)/32)):
		var d := span.x+16+i*32
		var f: Vector3 = (track.point(d+2)-track.point(d)).normalized()
		var basis := Basis(Vector3.UP,track.heading(d)).rotated(Vector3(-f.z,0,f.x).normalized(),asin(f.y))
		for side in [-1,1]: lamps.append(Transform3D(basis.scaled_local(Vector3(0.16,0.08,24)),track.point(d,side*(track.half_width(d)-0.4))+Vector3.UP*5.8))
	boxes(mat(Color("b9def1"),0,1.5),lamps,false)
	for ratio in [0.08,0.5,0.92]:
		var light := OmniLight3D.new()
		light.position = track.point(lerpf(span.x,span.y,ratio))+Vector3.UP*5
		light.light_color = Color("c9e7f3")
		light.light_energy = 0.7
		light.omni_range = 65
		add_child(light)
	var sign := Label3D.new()
	sign.text = "TUNNEL / %d m" % int(span.y-span.x)
	sign.font_size = 72
	sign.pixel_size = 0.009
	sign.position = track.point(span.x)+Vector3.UP*9
	sign.rotation.y = track.heading(span.x)
	add_child(sign)

func _process(delta: float) -> void:
	for node in rotating: node.rotate_object_local(Vector3.FORWARD,delta * 0.16)
