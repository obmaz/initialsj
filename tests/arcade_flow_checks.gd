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
	race.choose_mode("track", 0)
	check(race.track.active.get_node("CircuitCheckpoint").get_child_count() == 8, "트랙은 출발점 포함 두 체크포인트를 표시한다")
	check(race.track.active.get_node("CherryAvenue").get_meta("tree_count") >= 100, "후지 트랙은 긴 벚꽃 가로수를 표시한다")
	for valid_gates in [5, 0]:
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		var half: float = race.track.length * .5
		var tracker = race.world_race.trackers[0]
		tracker.gates_passed = valid_gates
		tracker.next_gate = tracker.start_distance + half
		race.world_race.teleport(0, half - 10, 0, false)
		race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 20
		race.time_left = 100
		for i in range(80):
			await tree.physics_frame
			race.step(1.0 / 60, 0, false, true, false)
		check(race.circuit_checkpoint == 2, "실제 차량이 반 바퀴 지점의 체크포인트를 지난다")
		check((race.time_left > 100) == (valid_gates == 5), "그리드80m 차이를 고려한 정상 통과만 시간을 주고 게이트 없는 지름길은 거부한다")
	race.finish()
	var elapsed: float = race.elapsed
	race.update_camera(.5)
	var previous: Vector3 = race.camera.position
	race.update_camera(.5)
	check(race.camera.position.distance_to(previous) > .1 and race.elapsed == elapsed, "결과에서는 공식 시간을 멈추고 중계 카메라만 이동한다")
	race.motion_reduced = true
	race.update_camera(.5)
	previous = race.camera.position
	race.update_camera(.5)
	check(race.camera.position.is_equal_approx(previous), "동작 감소는 결과 카메라 회전을 멈춘다")
	race.free()
	await tree.process_frame
	print("두 체크포인트 실제 통과·지름길 방지 / 벚꽃 가로수 / 결과 카메라: ", "PASS" if failures == 0 else "FAIL")
	return failures
