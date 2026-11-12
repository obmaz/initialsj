extends RefCounted
const Library = preload("res://scripts/track/route_library.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func set_car(race: Node3D, d: float, lane: float, speed: float) -> void:
	race.world_race.teleport(0, d, lane)
	race.world_race.player_body.grounded = true
	race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * speed
	race.speed = speed


func drive_axis(race: Node3D, lane: float = 0.0) -> float:
	var body: CharacterBody3D = race.world_race.player_body
	var look := clampf(race.speed * 0.55, 18, 42)
	var direction: Vector3 = race.track.point(race.distance + look, lane) - body.feet_position()
	var forward: Vector3 = body.forward_direction()
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	var angle := atan2(direction.dot(right), direction.dot(forward))
	var wheel: float = (
		(0.46 + race.vehicle.handling * 0.007) / (1 + race.speed * 0.035) * body.steering_scale(race.speed)
	)
	return clampf(atan(5.4 * sin(angle) / look) / wheel, -1, 1)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	race.state = "racing"
	await tree.physics_frame
	check(race.world_race != null and race.track.active.has_node("WorldCollision"), "투어도 실제 3D 차체와 노면 충돌체를 사용해야 한다")
	for preview in race.track.previews:
		check(preview.has_node("WorldCollision"), "분기 양쪽 도로를 진입 전에 충돌 월드에 등록해야 한다")
	for frame in range(158):
		race.step(1.0 / 60, 0, false, true, false)
	check(
		(
			race.speed > 38
			and race.speed < 46
			and race.world_race.player_body.feet_position().distance_to(race.track.point(80, -3.2)) > 45
		),
		"30% 낮춘 가속은 실제 차체를 전진시키고 이전 가속 속도에 도달하지 않아야 한다"
	)
	# 계측값만 변경해도 실제 차체가 도로 좌표로 순간 이동하지 않는다.
	var actual: Vector3 = race.world_race.player_body.position
	race.distance = 500
	race.lane = 3
	race.step(1.0 / 60, 0, false, false, false)
	check(race.world_race.player_body.position.distance_to(actual) < 2, "계측 좌표가 실제 차체 위치를 강제해서는 안 된다")
	set_car(race, 120, 0, 50)
	for frame in range(ceili(50.0 / float(race.vehicle.brake) * 60)):
		race.step(1.0 / 60, 0, false, true, true)
	check(race.speed < 1.6 and race.braking, "브레이크는 실제 차체 속도를 줄여야 한다")
	# 실제 체크포인트를 통과하고 모든 차량으로 좌·우 분기를 연속 주행한다.
	for vehicle in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		for side in [0, 1]:
			race.open_garage()
			race.select_vehicle(vehicle)
			race.restart()
			race.state = "racing"
			await tree.physics_frame
			set_car(race, race.track.active.checkpoint_distance() - 3, 0, 65)
			for frame in range(5):
				race.step(1.0 / 60, 0, false, true, false)
			check(race.checkpoints == 1 and race.route_choices_visible(), "실제 체크포인트 통과 후 선택과 시간 보상을 제공해야 한다")
			race.select_route(side)
			var last: Vector3 = race.world_race.player_body.position
			var max_step := 0.0
			for frame in range(500):
				race.step(1.0 / 60, 0, false, true, false)
				var world: Vector3 = race.world_race.player_body.position
				max_step = maxf(max_step, world.distance_to(last))
				last = world
				if race.stage_index == 1:
					break
			print(
				"분기 차량 ",
				vehicle,
				" 방향 ",
				side,
				" stage ",
				race.stage_index,
				" lane ",
				race.lane,
				" walls ",
				race.wall_hits,
				" d ",
				race.distance
			)
			check(
				race.stage_index == 1 and race.route_node == side and race.checkpoints == 1,
				"모든 차량은 선택한 실제 분기로 진입하고 보상을 중복 지급하지 않아야 한다"
			)
			check(race.wall_hits == 0 and max_step < 2.5, "분기 연결부에는 숨은 장벽이나 순간 이동이 없어야 한다")
	# 다섯 구간을 실제 끝점으로 통과하고 랩 카운터를 증가시키지 않는다.
	race.restart()
	race.state = "racing"
	for stage in range(5):
		await tree.physics_frame
		if stage < 4:
			race.award_checkpoint()
		set_car(race, race.track.length + (Library.FORK_COMMIT - 1 if stage < 4 else -1), -4, 50)
		for frame in range(3):
			race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "finished" and race.stage_index == 4 and race.laps_completed == 0, "투어는 랩 대신 다섯 구간 뒤 완주해야 한다")
	race.state = "racing"
	race.time_left = 0.001
	set_car(race, race.track.length - 0.02, 0, 80)
	race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "finished", "남은 시간 안에 실제 결승선을 넘으면 완주해야 한다")
	race.restart()
	race.state = "racing"
	race.time_left = 0.001
	race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "failed", "시간이 끝난 투어는 체크포인트로 되살아나지 않아야 한다")
	race.queue_free()
	await tree.process_frame
	print("투어 실제 3D 차체 / 체크포인트 / 분기 / 완주: ", "PASS" if failures == 0 else "FAIL")
	return failures
