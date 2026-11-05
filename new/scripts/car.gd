extends Node3D

var paint := Color("d93257")
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
	wedge(Vector3(0, 0.4, 0), Vector2(2.08, 4.35), Vector2(1.92, 3.95), 0.5, 0.08, shell)
	block(Vector3(0, 0.86, -1.35), Vector3(1.94, 0.15, 1.6), shell)
	wedge(Vector3(0, 0.93, 0.1), Vector2(1.7, 2.2), Vector2(1.45, 1.25), 0.52, 0.16, glass)
	block(Vector3(0, 1.48, 0.15), Vector3(1.46, 0.09, 1.25), shell)
	block(Vector3(0, 0.43, 2.19), Vector3(1.9, 0.26, 0.1), dark)
	block(Vector3(0, 0.42, -2.21), Vector3(2.12, 0.12, 0.25), dark)
	for x in [-0.57, 0.57]:
		block(Vector3(x, 0.87, 2.19), Vector3(0.72, 0.09, 0.05), mat(Color("ff3158"), 0, true))
		block(Vector3(x, 0.81, -2.19), Vector3(0.65, 0.08, 0.05), mat(Color("c6f3ff"), 0, true))
		block(Vector3(x, 1.02, 1.76), Vector3(0.08, 0.6, 0.12), dark)
		var flame := block(Vector3(x, 0.47, 2.7), Vector3(0.16, 0.16, 1.1), mat(Color("38d9ff"), 0, true))
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
		particles.initial_velocity_max = 3
		particles.gravity = Vector3(0, 0.6, 0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 2.5
		var puff := SphereMesh.new()
		puff.radius = 0.18
		puff.height = 0.36
		particles.mesh = puff
		particles.material_override = mat(Color("b4c3ce"))
		body.add_child(particles)
		particles.position = Vector3(x, 0.25, 1.4)
		smoke.append(particles)
	block(Vector3(0, 1.35, 1.8), Vector3(2.4, 0.12, 0.6), dark)
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

func animate(steer: float, drifting: bool, boosting: bool, delta: float) -> void:
	body.rotation.z = lerp(body.rotation.z, -steer * 0.06, delta * 8)
	body.rotation.y = lerp_angle(body.rotation.y, -steer * (0.28 if drifting else 0.06), delta * 6)
	for particles in smoke:
		particles.emitting = drifting
	for flame in nitro_flames:
		flame.visible = boosting
		flame.scale.z = randf_range(0.8, 1.7)

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
		for index in [face[0], face[2], face[1], face[0], face[3], face[2]]:
			st.add_vertex(vertices[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	body.add_child(node)
	node.position = pos
