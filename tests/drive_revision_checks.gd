extends RefCounted
const Recovery = preload("res://scripts/race/recovery_state.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var detector := Recovery.new()
	detector.advance(.1, Vector3.ZERO)
	detector.advance(2, Vector3(0, 0, 7))
	check(detector.available, "옆으로7m 미끄러져도 앞으로3m 못 가면 복구를 제공한다")
	detector.advance(.1, Vector3(4, 0, 7))
	check(not detector.available, "앞으로3m 이동하면 정체 타이머가 풀린다")
	detector.advance(.01, Vector3(4, 0, 7), Vector3.RIGHT, deg_to_rad(60))
	check(detector.available, "도로에 대해60도 꺾이면 즉시 복구를 제공한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.auto_accelerate = true
	race.hud.configure_pedals()
	var gas_at: Vector2 = race.hud.buttons.gas.get_center()
	check(not race.hud.hit_button("gas", gas_at) and race.hud.hit_button("brake", gas_at), "자동 가속에서는 가속 자리가 브레이크가 된다")
	race.state = "racing"
	for frame in range(60):
		await tree.physics_frame
		race._physics_process(1.0 / 60)
	check(race.throttling and race.speed > 10, "가속 입력 없이 실제 입력 루프에서 차량이 가속한다")
	var accelerated: float = race.speed
	race.hud.fingers[90] = gas_at
	for frame in range(12):
		await tree.physics_frame
		race._physics_process(1.0 / 60)
	check(
		race.braking and race.speed < accelerated - float(race.vehicle.brake) * .2 * .8, "자동 가속 중에도 옮겨진 브레이크 입력이 우선한다"
	)
	race.hud.fingers.clear()
	race.toggle_auto_accelerate()
	check(race.hud.hit_button("gas", gas_at) and not race.hud.hit_button("brake", gas_at), "자동 가속을 끄면 수동 페달 두 개로 복귀한다")
	race.preferences_path = "user://revision_settings.cfg"
	race.save_records = true
	race.auto_accelerate = true
	race.save_preferences()
	race.auto_accelerate = false
	race.load_preferences()
	check(race.auto_accelerate, "자동 가속 선택은 앱을 다시 열어도 유지된다")
	DirAccess.remove_absolute(race.preferences_path)
	race.save_records = false
	race.choose_mode("track", 1)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	var board: Node3D = race.track.active.speedway_board
	board.storage_path = "user://revision_laps.cfg"
	DirAccess.remove_absolute(board.storage_path)
	board.bind(race)
	race.elapsed = 62
	var world: Node3D = race.world_race
	var finish: float = race.track.length + 80
	world.teleport(0, finish - 3, 0)
	var tracker: RefCounted = world.trackers[0]
	tracker.gates_passed = 11
	tracker.next_gate = finish
	world.player_body.velocity = world.player_body.forward_direction() * 30
	race.speed = 30
	for frame in range(24):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, true, false)
	check(race.laps_completed == 1 and board.last_lap == race.last_lap, "실제 차체가 랩 선을 통과하면 그 랩 기록이 즉시 전광판에 반영된다")
	check(
		board.records.size() == 1 and board.labels[4].text.contains(board.stamp(race.last_lap)),
		"완주 전에도 실제 개인 베스트 랩을 표시한다"
	)
	board.add_result(60.5, str(race.vehicle.name), true)
	board.bind(race)
	check(
		board.records[0].time == 60.5 and board.personal[str(race.vehicle.name)] == 60.5,
		"전광판 랩 순위·개인 기록은 저장 후 다시 읽어도 유지된다"
	)
	DirAccess.remove_absolute(board.storage_path)
	world.safe_distance = 500
	world.safe_lane = 0
	check(world.recover_player(), "안전한 실제 도로에 복구할 수 있어야 한다")
	check(is_equal_approx(race.speed * 3.6, 100) and race.protection_left == 3, "복구는100km/h·3초 보호로 시작한다")
	var motor: CharacterBody3D = world.player_body
	check(motor.collision_mask == 35 and motor.collision_layer == 16, "보호 중 도로·가드와 차량·장애물 층을 구분한다")
	check(race.player.protection_active, "플레이어 차체에 불투명 보호 색상을 표시한다")
	var other: Node3D = race.rivals[0].car
	check(not other.protection_active, "공유 재질을 바꾸어 상대 차량까지 보호 색상으로 만들면 안 된다")
	for frame in range(210):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, true, false)
	check(
		race.protection_left == 0 and motor.collision_mask == 47 and not race.player.protection_active,
		"3초가 지나면 실제 충돌과 일반 외형으로 복귀한다"
	)
	var rail_d := 800.0
	var forward: Vector3 = (race.track.point(rail_d + 2) - race.track.point(rail_d - 2)).normalized()
	var right: Vector3 = (race.track.point(rail_d, 1) - race.track.point(rail_d)).normalized()
	var edge: float = race.track.half_width(rail_d) + race.track.active.rail_setback(rail_d, 1)
	world.teleport(0, rail_d, edge - 3.5, false)
	motor.reset_pose(race.track.point(rail_d, edge - 3.5), (forward + right).normalized(), world.road_up(rail_d))
	motor.velocity = motor.forward_direction() * 95
	race.speed = 95
	race.protection_left = 3
	var guard_hit := false
	for frame in range(24):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, false, false)
		for hit in motor.last_contacts:
			guard_hit = guard_hit or hit.barrier
	check(
		guard_hit and not race.crash.active and race.lane < edge + 1,
		(
			"보호 중300km/h 이상으로 부딪혀도 가드를 관통하거나 넘어서 날아가지 않는다: %s/%s/%.1f/%.1f"
			% [guard_hit, race.crash.active, race.lane, edge]
		)
	)
	# 실제 바닥이 사라진 구간에서도 보호 중에만 도로 높이에 접지한다.
	race.choose_mode("track", 4)
	race.restart()
	race.state = "racing"
	world = race.world_race
	motor = world.player_body
	for rival in race.rivals:
		rival.active = false
	var collapse: Node3D = race.track.active.collapse
	collapse.advance(5, 300)
	var d: float = collapse.span.x + 15
	var lane: float = race.track.active.surface_lane(6, d)
	world.teleport(0, d, lane, false)
	race.protection_left = 3
	motor.velocity = motor.forward_direction() * (100.0 / 3.6)
	race.speed = 100.0 / 3.6
	for frame in range(25):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, true, false)
	check(motor.feet_position().y >= race.track.point(race.distance, race.lane).y - .3, "보호 중에는 붕괴로 뚫린 노면에서도 떨어지지 않는다")
	# 실제 낙석은 파손된 뒤 남은 이동을 막지 않는다.
	var debris := preload("res://scripts/physics/road_debris.gd").new()
	debris.collision_layer = 8
	debris.receive_debris_hit()
	check(debris.broken and debris.collision_layer == 0 and not debris.visible, "파손된 바위는 충돌과 외형을 함께 제거한다")
	debris.free()
	race.queue_free()
	await tree.process_frame
	print("자동 가속 페달 / 실제 랩 전광판·저장 / 100km 복구·3초 보호 / 붕괴 노면·파손 장애물: ", "PASS" if failures == 0 else "FAIL")
	return failures
