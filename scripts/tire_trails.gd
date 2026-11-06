extends Node3D
# A fixed pool: one draw call and bounded memory, regardless of race length.
const CAPACITY := 160
var instances := MultiMesh.new()
var material := ShaderMaterial.new()
var cursor := 0
var previous: Array[Vector3] = []

func _ready() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.24, 1)
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = CAPACITY
	material.shader = preload("res://shaders/tire_trail.gdshader")
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = instances
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	reset()

func reset() -> void:
	previous.clear()
	cursor = 0
	for i in range(CAPACITY):
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled_local(Vector3.ZERO), Vector3.ZERO))
		instances.set_instance_custom_data(i, Color(-1000, 0, 0, 0))

func update(race: Node3D) -> void:
	material.set_shader_parameter("clock", race.elapsed)
	if race.state != "racing" or race.air.active or not race.drifting or absf(race.lane) > race.track.half_width(race.distance)-1.1:
		previous.clear()
		return
	var points: Array[Vector3] = []
	for wheel_index in [1, 3]:
		var wheel: Node3D = race.player.wheels[wheel_index]
		var p: Vector3 = race.player.body.to_global(wheel.position)
		if race.world_race != null:
			var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*1.5,1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): previous.clear(); return
			p = hit.position+hit.normal*0.04
		else: p.y = race.track.point(race.distance - wheel.position.z).y + 0.045
		points.append(p)
	if previous.is_empty():
		previous = points
		return
	var traveled := previous[0].distance_to(points[0])
	if traveled < 1.2:
		return
	if traveled < 7:
		for i in range(2):
			var direction := points[i] - previous[i]
			var basis := Basis.looking_at(direction.normalized(), Vector3.UP).scaled_local(Vector3(1, 1, direction.length()))
			instances.set_instance_transform(cursor, Transform3D(basis, (points[i] + previous[i]) / 2))
			instances.set_instance_custom_data(cursor, Color(race.elapsed, 0, 0, 1))
			cursor = (cursor + 1) % CAPACITY
	previous = points
