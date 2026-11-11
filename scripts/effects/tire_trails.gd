extends Node3D
# 고정 순환 풀을 한 번에 그린다. 자국은 월드 좌표에 남고 경기 길이에 비례해 메모리가 늘지 않는다.
const RaceState = preload("res://scripts/race/race_state.gd")
const CAPACITY := 1536
var instances := MultiMesh.new()
var material := ShaderMaterial.new()
var cursor := 0
var previous: Array[Vector3] = []
var previous_normals: Array[Vector3] = []


func _ready() -> void:
	var mesh := preload("res://scripts/rendering/primitive_assets.gd").mesh("tire_trail")
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
	previous_normals.clear()
	cursor = 0
	for i in range(CAPACITY):
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled_local(Vector3.ZERO), Vector3.ZERO))
		instances.set_instance_custom_data(i, Color(-1000, 0, 0, 0))


func update(race: Node3D) -> void:
	material.set_shader_parameter("clock", race.elapsed)
	if race.state == RaceState.PAUSED:
		return
	var contact: bool = race.world_race == null or race.world_race.player_body.grounded
	if (
		race.state != RaceState.RACING
		or race.air.active
		or not contact
		or race.speed < 8
		or not (race.drifting or (race.braking and race.speed > 24))
		or absf(race.lane) > race.track.half_width(race.distance) - 1.1
	):
		previous.clear()
		previous_normals.clear()
		return
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for wheel_index in [1, 3]:
		var wheel: Node3D = race.player.wheels[wheel_index]
		var p: Vector3 = race.player.body.to_global(wheel.position)
		var normal := Vector3.UP
		if race.world_race != null:
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p - Vector3.UP * 1.5, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				previous.clear()
				previous_normals.clear()
				return
			normal = hit.normal
			p = hit.position + normal * 0.018
		else:
			p.y = race.track.point(race.distance - wheel.position.z).y + 0.045
		points.append(p)
		normals.append(normal)
	if previous.is_empty():
		previous = points
		previous_normals = normals
		return
	var traveled := previous[0].distance_to(points[0])
	if traveled < .75:
		return
	if traveled < 10:
		for i in range(2):
			var strength := clampf(.55 + absf(race.slip_angle) * 1.8 + absf(race.steer) * .25, .55, 1)
			segment(previous[i], points[i], (normals[i] + previous_normals[i]).normalized(), race.elapsed, strength)
	previous = points
	previous_normals = normals


func segment(a: Vector3, b: Vector3, normal: Vector3, born: float, strength: float) -> void:
	var direction := b - a
	var tangent := direction.slide(normal)
	if tangent.length_squared() < .001:
		return
	instances.set_instance_transform(cursor, mark_transform(a, b, normal))
	instances.set_instance_custom_data(cursor, Color(born, strength, direction.length(), 1))
	cursor = (cursor + 1) % CAPACITY


static func mark_transform(a: Vector3, b: Vector3, normal: Vector3) -> Transform3D:
	var direction := b - a
	var basis := Basis.looking_at(direction.slide(normal).normalized(), normal).scaled_local(
		Vector3(1, 1, direction.length() + .04)
	)
	return Transform3D(basis, (a + b) / 2)
