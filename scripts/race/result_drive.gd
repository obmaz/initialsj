extends RefCounted
# 종료 기록·게이트·보상과 분리된 짧은 실제 차체 관성 주행과 중계 구도.
const State = preload("res://scripts/race/race_state.gd")
const Progress = preload("res://scripts/race/tour_progress.gd")
const Recovery = preload("res://scripts/race/road_recovery.gd")
var initialized := false
var stopped := true
var distance := 0.0
var lane := 0.0
var coast_speed := 0.0
var deceleration := 6.0
var age := 0.0
var query_clock := 0.0
var clear_until := 0.0


func reset() -> void:
	initialized = false
	stopped = true
	age = 0


func begin(race: Node3D) -> void:
	initialized = true
	age = 0
	distance = race.distance
	lane = race.lane
	var body: CharacterBody3D = race.world_race.player_body
	coast_speed = maxf(0, body.velocity.dot(body.forward_direction()))
	deceleration = maxf(6, coast_speed / 6)
	stopped = (race.mode == "tour" and race.state == State.FINISHED) or not body.grounded or coast_speed < .5
	query_clock = 0
	clear_until = distance
	race.cancel_nitro()
	race.throttling = false
	race.braking = false
	race.drifting = false
	race.boosting = false
	body.rescue_floor.clear()


func clearance(race: Node3D) -> float:
	var body: CharacterBody3D = race.world_race.player_body
	var space := body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.contact_shape.shape
	query.margin = .15
	query.collision_mask = 14
	query.exclude = [body.get_rid()]
	var horizon := coast_speed * coast_speed / (2 * deceleration) + 16
	for ahead in range(0, ceili(horizon) + 8, 8):
		var d := distance + ahead
		if not race.track.active.closed_loop and d >= race.track.length - 18:
			return maxf(0, ahead - 8)
		if absf(lane) + 1.4 >= race.track.half_width(d):
			return maxf(0, ahead - 8)
		var forward: Vector3 = (race.track.point(d + 1) - race.track.point(d - 1)).normalized()
		var right: Vector3 = (race.track.point(d, 1) - race.track.point(d, -1)).normalized()
		var up := right.cross(forward).normalized()
		var center: Vector3 = race.track.point(d, lane)
		var floor_hit := Recovery.stable_hit(space, center, up, 2)
		if floor_hit.is_empty():
			return maxf(0, ahead - 8)
		for side in [-1.3, 1.3]:
			if Recovery.stable_hit(space, center + right * side, up, 2).is_empty():
				return maxf(0, ahead - 8)
		query.transform = Transform3D(
			Basis.looking_at(forward, floor_hit.normal), floor_hit.position + floor_hit.normal * .72
		)
		if not space.intersect_shape(query, 1).is_empty():
			return maxf(0, ahead - 8)
	return horizon


func stop(race: Node3D) -> void:
	stopped = true
	coast_speed = 0
	race.speed = 0
	race.world_race.player_body.velocity = Vector3.ZERO
	race.steer = 0


func advance(race: Node3D, delta: float) -> void:
	if not initialized:
		begin(race)
	if stopped:
		return
	age += delta
	var body: CharacterBody3D = race.world_race.player_body
	query_clock -= delta
	if query_clock <= 0:
		query_clock = .2
		clear_until = distance + clearance(race)
	var available := maxf(0, clear_until - distance - 5)
	var target_speed := minf(coast_speed, sqrt(2 * deceleration * available))
	coast_speed = move_toward(target_speed, 0, deceleration * delta)
	if age >= 8 or coast_speed < .5 or available < .5 or not body.grounded:
		stop(race)
		return
	var look := clampf(coast_speed * .65, 12, 40)
	var direction: Vector3 = race.track.point(distance + look, lane) - body.feet_position()
	var forward: Vector3 = body.forward_direction()
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	var angle := atan2(direction.dot(right), direction.dot(forward))
	if absf(angle) > 1.05:
		stop(race)
		return
	var wheel: float = (
		(.46 + race.vehicle.handling * .007) / (1 + coast_speed * .035) * body.steering_scale(coast_speed)
	)
	var axis := clampf(atan(5.4 * sin(angle) / look) / wheel, -.7, .7)
	body.road_heading = (race.track.point(distance + 2) - race.track.point(distance - 2)).normalized()
	body.advance(delta, axis, coast_speed, false)
	coast_speed = minf(coast_speed, race.world_race.speed_of(body))
	race.speed = coast_speed
	race.steer = body.steering
	distance = Progress.project_distance(race.track, body.feet_position(), distance)
	race.player.body_motion.sample(delta, body.velocity, body.global_basis, body.grounded)
	if not body.last_contacts.is_empty():
		stop(race)


func update_camera(race: Node3D, delta: float) -> void:
	race.result_age += delta
	var body: CharacterBody3D = race.world_race.player_body
	var forward: Vector3 = body.forward_direction()
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	var views := [Vector3(5.5, 3.0, -9), Vector3(-6, 2.3, 7.5), Vector3(3.5, 7.0, -7)]
	var index := 0 if race.motion_reduced else int(race.result_age / 4.5) % views.size()
	var view: Vector3 = views[index]
	var target: Vector3 = race.player.global_position + Vector3.UP * .8
	var wanted: Vector3 = target + right * view.x + Vector3.UP * view.y + forward * view.z
	var query := PhysicsRayQueryParameters3D.create(target, wanted, 3, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted = hit.position + hit.normal * .35
	# 구도는 천천히 이동하며 화면 오른쪽 결과 카드가 차를 가리지 않도록 시선을 옮긴다.
	race.camera_offset = race.camera_offset.lerp(wanted - target, 1 - exp(-delta * 3.5))
	if race.motion_reduced:
		race.camera_offset = wanted - target
	race.camera.global_position = target + race.camera_offset
	var screen_right: Vector3 = (target - race.camera.global_position).normalized().cross(Vector3.UP).normalized()
	race.camera.look_at(target + screen_right * 2.4)
	race.camera.fov = lerpf(race.camera.fov, 62, 1 - exp(-delta * 3))
	race.camera.reset_physics_interpolation()
