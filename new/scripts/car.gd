extends Node3D

var paint := Color("b51223")
var model := "sport"
var wheel_half_track := 1.02
var wheel_half_base := 1.35
var wheel_thickness := 0.3
var rim_scale := 1.0
var ride_offset := 0.0
var nitro_tint := Color("56dfff")
var wheel_radius := 0.43
var road_speed := 0.0
var traffic := false
var material_cache := {}
var headlight: SpotLight3D
var traffic_wheels: MultiMeshInstance3D
var nitro_flames: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var nitro_glows: Array[MeshInstance3D] = []
var smoke: Array[CPUParticles3D] = []
var brake_lights: Array[StandardMaterial3D] = []
var body: Node3D

func mat(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(),metal,glow]
	if material_cache.has(key): return material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.27
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	material_cache[key] = m
	return m

func block(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	body.add_child(n)
	n.position = pos
	return n

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	if model == "hatch":
		wheel_radius = 0.37
		wheel_half_track = 0.82
		wheel_half_base = 1.25
		wheel_thickness = 0.22
		rim_scale = 0.86
		ride_offset = -0.12
		preload("res://scripts/hatch_body.gd").build(self)
	elif model in ["wedge","muscle"]:
		wheel_radius = 0.38 if model == "wedge" else 0.40
		wheel_half_track = 0.94 if model == "wedge" else 0.90
		wheel_half_base = 1.32 if model == "wedge" else 1.30
		wheel_thickness = 0.30 if model == "wedge" else 0.28
		rim_scale = 1.0 if model == "wedge" else 0.94
		ride_offset = -0.12
		preload("res://scripts/custom_bodies.gd").build(self)
	else:
		make_sport_body()
	body.position.y = ride_offset
	make_drift_smoke()
	make_wheels()
	merge_static_body()

func make_sport_body() -> void:
	var shell := mat(paint, 0.55)
	shell.clearcoat_enabled = true
	shell.roughness = 0.20
	shell.clearcoat = 0.35
	shell.clearcoat_roughness = 0.12
	var dark := mat(Color("10212d"), 0.5)
	var glass := mat(Color("253e50"), 0.75)
	make_body_shell(shell)
	block(Vector3(0, 0.86, -1.35), Vector3(1.75, 0.08, 1.35), shell)
	wedge(Vector3(0, 0.93, 0.1), Vector2(1.7, 2.2), Vector2(1.45, 1.25), 0.38, 0.16, glass)
	block(Vector3(0, 1.34, 0.15), Vector3(1.46, 0.09, 1.25), shell)
	wedge(Vector3(0, 0.24, 2.15), Vector2(1.5, 0.26), Vector2(1.9, 0.25), 0.30, 0, dark)
	block(Vector3(0, 0.42, -2.21), Vector3(2.12, 0.12, 0.25), dark)
	for x in [-0.50, 0.50]:
		var lamp := mat(Color("ff2620"),0,true)
		brake_lights.append(lamp)
		block(Vector3(x,0.87,2.19),Vector3(0.66,0.055,0.05),lamp)
		block(Vector3(x, 0.81, -2.19), Vector3(0.65, 0.08, 0.05), mat(Color("c6f3ff"), 0, true))
		block(Vector3(x, 1.01, 1.76), Vector3(0.08, 0.32, 0.12), dark)
		var exhaust := MeshInstance3D.new()
		var pipe := TorusMesh.new()
		pipe.inner_radius = 0.08
		pipe.outer_radius = 0.13
		pipe.rings = 12
		pipe.ring_segments = 6
		exhaust.mesh = pipe
		exhaust.material_override = mat(Color("78818c"), 0.9)
		body.add_child(exhaust)
		exhaust.position = Vector3(x, 0.47, 2.30)
		exhaust.rotation.x = PI / 2
		var flame := MeshInstance3D.new()
		var plume := CylinderMesh.new()
		plume.top_radius = 0.015
		plume.bottom_radius = 0.18
		plume.height = 1.2
		plume.radial_segments = 12
		plume.cap_top = false
		plume.cap_bottom = false
		flame.mesh = plume
		var plume_material := ShaderMaterial.new()
		plume_material.shader = preload("res://shaders/nitro_flame.gdshader")
		flame.material_override = plume_material
		body.add_child(flame)
		flame.position = Vector3(x, 0.47, 2.78)
		flame.rotation.x = PI / 2
		nitro_flames.append(flame)
		flame.visible = false
		var glow := MeshInstance3D.new()
		var glow_mesh := QuadMesh.new()
		glow_mesh.size = Vector2(0.55, 0.55)
		glow.mesh = glow_mesh
		var glow_material := ShaderMaterial.new()
		glow_material.shader = preload("res://shaders/nitro_glow.gdshader")
		glow.material_override = glow_material
		body.add_child(glow)
		glow.position = Vector3(x, 0.47, 2.38)
		glow.visible = false
		nitro_glows.append(glow)
	block(Vector3(0, 0.895, 1.36), Vector3(1.6, 0.035, 1.25), dark)
	for i in range(6):
		block(Vector3(0, 0.925, 0.90 + i * 0.135), Vector3(1.48, 0.035, 0.065), dark)
	for side in [-1, 1]:
		block(Vector3(side * 1.1, 1.02, -0.45), Vector3(0.24, 0.12, 0.32), shell)
	block(Vector3(0, 1.17, 1.8), Vector3(2.2, 0.08, 0.36), dark)

func make_drift_smoke() -> void:
	for x in [-0.8, 0.8]:
		var particles := CPUParticles3D.new()
		particles.amount = 22
		particles.lifetime = 0.7
		particles.emitting = false
		particles.local_coords = false
		particles.direction = Vector3(0, 0.3, 1)
		particles.spread = 35
		particles.initial_velocity_min = 1
		particles.initial_velocity_max = 5
		particles.gravity = Vector3(0, 0.6, 0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 2.5
		var puff := QuadMesh.new()
		puff.size = Vector2(1.2, 1.2)
		particles.mesh = puff
		var smoke_mat := ShaderMaterial.new()
		smoke_mat.shader = preload("res://shaders/tire_smoke.gdshader")
		particles.material_override = smoke_mat
		var fade := Gradient.new()
		fade.set_color(0, Color(0.78, 0.83, 0.9, 0.4))
		fade.set_color(1, Color(0.78, 0.83, 0.9, 0))
		particles.color_ramp = fade
		body.add_child(particles)
		particles.position = Vector3(x, 0.25, wheel_half_base)
		smoke.append(particles)

func make_wheels() -> void:
	var rim_mesh := make_rim_mesh()
	var axle := wheel_half_track
	var wheelbase := wheel_half_base
	for x in [-axle, axle]:
		for z in [-wheelbase, wheelbase]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = wheel_radius
			mesh.bottom_radius = wheel_radius
			mesh.height = wheel_thickness
			mesh.radial_segments = 24
			wheel.mesh = mesh
			wheel.material_override = mat(Color("131b23"))
			body.add_child(wheel)
			wheel.position = Vector3(x, wheel_radius + 0.02, z)
			wheel.rotation.z = PI / 2
			wheels.append(wheel)
			var rim := MeshInstance3D.new()
			rim.mesh = rim_mesh
			rim.scale = Vector3.ONE*rim_scale
			rim.material_override = mat(Color("737b7f") if model == "hatch" else Color("83939e"), 0.85)
			wheel.add_child(rim)
			rim.position.y = -signf(x) * (wheel_thickness*0.5+0.015)
			if x > 0:
				rim.rotation.z = PI

func animate(steer: float, drifting: bool, boosting: bool, delta: float, yaw: float = NAN, braking: bool = false, hit: float = 0) -> void:
	body.rotation.z = lerp(body.rotation.z, -steer * 0.06, delta * 8)
	body.rotation.y = lerp_angle(body.rotation.y,-steer*(0.40 if drifting else 0.07),delta*6) if is_nan(yaw) else yaw
	body.rotation.x = lerpf(body.rotation.x,0.07 if braking else 0.0,1-exp(-delta*8))
	body.position.y = ride_offset + sin(Time.get_ticks_msec()*0.05)*hit*0.08
	for lamp in brake_lights: lamp.emission_energy_multiplier = 4.5 if braking else 1.7
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, -road_speed * delta / wheel_radius)
	for particles in smoke:
		particles.emitting = drifting
	for glow in nitro_glows:
		glow.visible = boosting
	for flame in nitro_flames:
		flame.visible = boosting
		flame.scale.y = randf_range(0.85, 1.35)

func wedge(pos: Vector3, lower: Vector2, upper: Vector2, height: float, offset: float, material: Material) -> void:
	var vertices := PackedVector3Array([
		Vector3(-lower.x / 2, 0, -lower.y / 2), Vector3(lower.x / 2, 0, -lower.y / 2),
		Vector3(lower.x / 2, 0, lower.y / 2), Vector3(-lower.x / 2, 0, lower.y / 2),
		Vector3(-upper.x / 2, height, -upper.y / 2 + offset), Vector3(upper.x / 2, height, -upper.y / 2 + offset),
		Vector3(upper.x / 2, height, upper.y / 2 + offset), Vector3(-upper.x / 2, height, upper.y / 2 + offset)
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]:
		for index in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			st.add_vertex(vertices[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	body.add_child(node)
	node.position = pos

func make_body_shell(material: Material) -> void:
	var outline := [Vector2(-0.72, -2.2), Vector2(0.72, -2.2), Vector2(1.04, -1.55), Vector2(1.04, 1.55), Vector2(0.90, 2.2), Vector2(-0.90, 2.2), Vector2(-1.04, 1.55), Vector2(-1.04, -1.55)]
	var rings: Array[PackedVector3Array] = []
	for level in range(3):
		var ring := PackedVector3Array()
		for p: Vector2 in outline:
			var width := 0.94 if level == 0 else (1.0 if level == 1 else 0.92)
			var height := 0.36 if level == 0 else (0.65 if level == 1 else 0.87)
			ring.append(Vector3(p.x * width, height, p.y))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(2):
		for i in range(8):
			var j := (i + 1) % 8
			var points := [rings[level][i], rings[level][j], rings[level + 1][j], rings[level + 1][i]]
			for index in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(points[index])
	for i in range(8):
		for p: Vector3 in [Vector3(0, 0.87, 0), rings[2][i], rings[2][(i + 1) % 8]]:
			st.add_vertex(p)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	body.add_child(node)

func make_rim_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a := TAU * i / 32.0
		var b := TAU * (i + 1) / 32.0
		var u := Vector3(cos(a), 0, sin(a))
		var v := Vector3(cos(b), 0, sin(b))
		var points := [u * 0.235, u * 0.285, v * 0.235, v * 0.285]
		for index in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(points[index])
	var spoke_count := 8 if model == "hatch" else (6 if model == "wedge" else 5)
	for i in range(spoke_count):
		var angle := TAU * i / spoke_count
		var direction := Vector3(cos(angle), 0, sin(angle))
		var width := Vector3(-direction.z, 0, direction.x) * 0.028
		var root_point := direction * 0.055
		var tip := direction * 0.25 + width * 0.5
		var points := [root_point - width, tip - width, root_point + width, tip + width]
		for index in [0, 1, 2, 1, 3, 2]:
			st.set_normal(Vector3.UP)
			st.add_vertex(points[index])
	for i in range(12):
		for p in [Vector3.ZERO, Vector3(cos(TAU * i / 12), 0, sin(TAU * i / 12)) * 0.075, Vector3(cos(TAU * (i + 1) / 12), 0, sin(TAU * (i + 1) / 12)) * 0.075]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()

# Untextured body pieces share a surface per material instead of individual draw calls.
func merge_static_body() -> void:
	var groups := {}
	for child in body.get_children():
		if not child is MeshInstance3D or child in wheels or child in nitro_flames or child in nitro_glows: continue
		var material: Material = child.material_override
		if not groups.has(material): groups[material] = []
		groups[material].append(child)
	for material in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in groups[material]:
			var arrays: Array = child.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty(): indices = PackedInt32Array(range(vertices.size()))
			for index in indices:
				surface.set_normal((child.transform.basis * normals[index]).normalized())
				surface.add_vertex(child.transform * vertices[index])
			body.remove_child(child)
			child.queue_free()
		surface.index()
		var merged := MeshInstance3D.new()
		merged.mesh = surface.commit()
		merged.material_override = material
		# Keep body shadows; tiny lights, glazing and far traffic details need none.
		if material.emission_enabled or material.albedo_color == Color("78818c") or material.albedo_color == Color("253e50") or (traffic and material.albedo_color != paint):
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(merged)
	if traffic:
		for wheel in wheels:
			wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for rim in wheel.get_children(): rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var tire := BoxMesh.new()
		tire.size = Vector3(0.3,0.76,0.8)
		multi.mesh = tire
		multi.instance_count = 4
		for i in range(4): multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(-1.02 if i < 2 else 1.02,0.45,-1.35 if i % 2 == 0 else 1.35)))
		traffic_wheels = MultiMeshInstance3D.new()
		traffic_wheels.multimesh = multi
		traffic_wheels.material_override = mat(Color("131b23"))
		traffic_wheels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(traffic_wheels)

func set_detail(distance_to_player: float) -> void:
	for wheel in wheels: wheel.visible = distance_to_player < 110
	if traffic_wheels != null: traffic_wheels.visible = distance_to_player >= 110

func add_boost_jet(pos: Vector3, radius: float) -> void:
	var flame := MeshInstance3D.new()
	var plume := CylinderMesh.new()
	plume.top_radius = 0.015
	plume.bottom_radius = radius
	plume.height = 1.2
	plume.radial_segments = 12
	plume.cap_top = false
	plume.cap_bottom = false
	flame.mesh = plume
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/nitro_flame.gdshader")
	material.set_shader_parameter("tint",nitro_tint)
	flame.material_override = material
	body.add_child(flame)
	flame.position = pos+Vector3(0,0,0.48)
	flame.rotation.x = PI/2
	flame.visible = false
	nitro_flames.append(flame)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*radius*4
	glow.mesh = quad
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://shaders/nitro_glow.gdshader")
	glow_material.set_shader_parameter("tint",nitro_tint)
	glow.material_override = glow_material
	body.add_child(glow)
	glow.position = pos+Vector3(0,0,0.08)
	glow.visible = false
	nitro_glows.append(glow)

func add_headlight(pos: Vector3) -> void:
	headlight = SpotLight3D.new()
	headlight.position = pos
	headlight.spot_range = 65
	headlight.spot_angle = 48
	headlight.light_color = Color("eaf3ff")
	headlight.light_energy = 2.5
	headlight.visible = false
	body.add_child(headlight)
