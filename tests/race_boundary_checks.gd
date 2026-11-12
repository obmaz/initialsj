extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("track", 1)
	for gap in [30.0, 100.0]:
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		var rival = race.rivals[0]
		rival.active = true
		rival.boost_cooldown = 100
		var world = race.world_race
		world.teleport(1, 2000, -3.2)
		var body = world.bodies[1]
		body.velocity = body.forward_direction() * 35
		body.grounded = true
		var traveled := 0.0
		var simulated := 0.0
		var start = body.position
		for frame in range(60):
			await tree.physics_frame
			world.teleport(0, world.trackers[1].distance - gap, 3.2)
			var before = body.position
			world.update_rivals(1.0 / 60)
			traveled += before.distance_to(body.position)
			simulated += rival.speed / 60
		check(absf(traveled / simulated - 1) < .06, "거리별 AI 물리 주기가 실제 이동량을 중복 적분하지 않는다")
	race.choose_mode("track", 0)
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	var half = race.track.length * .5
	var tracker = race.world_race.trackers[0]
	tracker.gates_passed = 5
	tracker.next_gate = tracker.start_distance + half
	race.world_race.teleport(0, half - .2, 0, false)
	race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 80
	race.speed = 80
	race.time_left = .001
	await tree.physics_frame
	race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "failed" and race.time_left == 0 and race.distance < half, "기한 뒤의 체크포인트로 경기를 되살릴 수 없다")
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	var final_line = race.track.length * 3 + 80
	tracker = race.world_race.trackers[0]
	tracker.gates_passed = 35
	tracker.laps = 2
	tracker.next_gate = final_line
	race.laps_completed = 2
	race.circuit_checkpoint = 7
	race.world_race.teleport(0, final_line - .2, 0, false)
	race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 80
	race.speed = 80
	race.time_left = .001
	await tree.physics_frame
	race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "failed" and race.distance < final_line, "기한 이후의 이동이 실패를 완주로 바꾸지 않는다")
	# 같은 마지막 틱이라도 기한 안에 선을 넘었으면 완주다.
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	tracker = race.world_race.trackers[0]
	tracker.gates_passed = 35
	tracker.laps = 2
	tracker.next_gate = final_line
	race.laps_completed = 2
	race.circuit_checkpoint = 7
	race.world_race.teleport(0, final_line - .02, 0, false)
	race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 80
	race.speed = 80
	race.time_left = .001
	await tree.physics_frame
	race.step(1.0 / 60, 0, false, true, false)
	check(race.state == "finished" and race.laps_completed == 3, "기한 안의 최종선 통과는 마지막 물리 틱에서도 완주한다")
	race.choose_mode("tour")
	race.restart()
	race.state = "racing"
	var traffic: Array = tree.get_nodes_in_group("tour_road_traffic").filter(
		func(node): return node.clock == race and node.road == race.track.active
	)
	var other = traffic[0]
	var original_position = other.global_position
	var original_distance = other.distance
	race.world_race.teleport(0, other.distance - 30, other.lane + 4)
	race.world_race.place_cars()
	race.world_race.update_camera(1)
	other.activated = true
	for frame in range(120):
		await tree.physics_frame
	check(other.distance > original_distance + 1, "교통 차량이 실제로 움직인 뒤 재시작을 검사한다")
	var original_id = other.get_instance_id()
	race.restart()
	check(not other.is_in_group("tour_road_traffic"), "지난 교통 차체는 실제 해제 전에도 즉시 관측 그룹에서 제외한다")
	await tree.process_frame
	traffic = tree.get_nodes_in_group("tour_road_traffic").filter(
		func(node): return node.clock == race and node.road == race.track.active
	)
	check(not is_instance_id_valid(original_id), "재시작은 이동·삭제된 교통 차체를 새 출발 상태로 교체한다")
	check(traffic.size() > 0 and not traffic[0].activated, "첫 구간 재시작도 교통 차량의 활성화 상태를 초기화한다")
	check(traffic[0].global_position.distance_to(original_position) < .1, "교통 차량 시작 위치를 복구한다")
	race.free()
	await tree.process_frame
	print("AI 이동량 / 기한 경계 / 투어 재시작: ", "PASS" if failures == 0 else "FAIL")
	return failures
