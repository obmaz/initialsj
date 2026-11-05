extends Node3D

var paint := Color("c91d32")
var road_speed := 0.0
var nitro_flames: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []
var smoke: Array[CPUParticles3D] = []
var body: Node3D

func mat(color: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.27
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
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
	var shell := mat(paint, 0.65)
	var dark := mat(Color("10212d"), 0.5)
	var glass := mat(Color("253e50"), 0.75)
	make_body_shell(shell)
	block(Vector3(0, 0.86, -1.35), Vector3(1.75, 0.08, 1.35), shell)
	wedge(Vector3(0, 0.93, 0.1), Vector2(1.7, 2.2), Vector2(1.45, 1.25), 0.38, 0.16, glass)
	block(Vector3(0, 1.34, 0.15), Vector3(1.46, 0.09, 1.25), shell)
	block(Vector3(0, 0.43, 2.19), Vector3(1.9, 0.26, 0.1), dark)
	block(Vector3(0, 0.42, -2.21), Vector3(2.12, 0.12, 0.25), dark)
	for x in [-0.57, 0.57]:
		block(Vector3(x, 0.87, 2.19), Vector3(0.72, 0.09, 0.05), mat(Color("ff2620"), 0, true))
		block(Vector3(x, 0.81, -2.19), Vector3(0.65, 0.08, 0.05), mat(Color("c6f3ff"), 0, true))
		block(Vector3(x, 1.01, 1.76), Vector3(0.08, 0.32, 0.12), dark)
		var flame := MeshInstance3D.new()
		var plume := CylinderMesh.new()
		plume.top_radius = 0.015
		plume.bottom_radius = 0.18
		plume.height = 1.2
		plume.radial_segments = 12
		flame.mesh = plume
		var plume_material := ShaderMaterial.new()
		plume_material.shader = preload("res://shaders/nitro_flame.gdshader")
		flame.material_override = plume_material
		body.add_child(flame)
		flame.position = Vector3(x, 0.47, 2.78)
		flame.rotation.x = PI / 2
		nitro_flames.append(flame)
		flame.visible = false
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
		particles.position = Vector3(x, 0.25, 1.4)
		smoke.append(particles)
	for i in range(6):
		block(Vector3(0, 0.925, 0.90 + i * 0.135), Vector3(1.48, 0.035, 0.065), dark)
	for side in [-1, 1]:
		block(Vector3(side * 1.1, 1.02, -0.45), Vector3(0.24, 0.12, 0.32), shell)
	block(Vector3(0, 1.17, 1.8), Vector3(2.2, 0.08, 0.36), dark)
	for x in [-1.02, 1.02]:
		for z in [-1.35, 1.35]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.43
			mesh.bottom_radius = 0.43
			mesh.height = 0.3
			mesh.radial_segments = 16
			wheel.mesh = mesh
			wheel.material_override = mat(Color("131b23"))
			body.add_child(wheel)
			wheel.position = Vector3(x, 0.45, z)
			wheel.rotation.z = PI / 2
			wheels.append(wheel)
			var rim := MeshInstance3D.new()
			var rim_mesh := CylinderMesh.new()
			rim_mesh.top_radius = 0.27
			rim_mesh.bottom_radius = 0.27
			rim_mesh.height = 0.025
			rim_mesh.radial_segments = 10
			rim.mesh = rim_mesh
			rim.material_override = mat(Color("83939e"), 0.85)
			wheel.add_child(rim)
			rim.position.y = -signf(x) * 0.165

func animate(steer: float, drifting: bool, boosting: bool, delta: float) -> void:
	body.rotation.z = lerp(body.rotation.z, -steer * 0.06, delta * 8)
	body.rotation.y = lerp_angle(body.rotation.y, -steer * (0.40 if drifting else 0.07), delta * 6)
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, -road_speed * delta / 0.43)
	for particles in smoke:
		particles.emitting = drifting
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
	var outline := [Vector2(-0.72, -2.2), Vector2(0.72, -2.2), Vector2(1.04, -1.55), Vector2(1.04, 1.55), Vector2(0.75, 2.2), Vector2(-0.75, 2.2), Vector2(-1.04, 1.55), Vector2(-1.04, -1.55)]
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
