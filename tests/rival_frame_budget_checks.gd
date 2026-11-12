extends RefCounted
const RivalState = preload("res://scripts/race/rival_state.gd")
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
	race.choose_mode("track", 1)
	race.restart()
	race.state = "racing"
	var session: Node3D = race.world_race
	var maximum := 0
	var total := 0
	for frame in range(15):
		var planned := 0
		for i in range(1, session.bodies.size()):
			var rival: RefCounted = race.rivals[i - 1]
			if frame == 0:
				check(is_equal_approx(rival.decision, RivalState.decision_phase(rival.id)), "롤링 배치도 차량별 판단 위상을 보존한다")
			if rival.decision <= 1.0 / 60:
				planned += 1
			session.rival_lane(i, rival.distance, 30, 1.0 / 60)
		maximum = maxi(maximum, planned)
		total += planned
	check(total == 15 and maximum <= 2, "15대의 첫 차선 판단을 한 틱에 몰지 않고 모든 차량에 배분한다")
	race.rivals[0].lod_time = .016
	session.teleport(1, 1000, -3.2)
	check(race.rivals[0].lod_time == 0, "재시작·복구 뒤 이전 물리 누적 시간이 남지 않는다")
	var tracker: RefCounted = session.trackers[1]
	var counters := [tracker.distance, tracker.gates_passed, tracker.laps, tracker.start_distance, tracker.next_gate]
	tracker.seed_carried_pose(session.bodies[1].feet_position())
	check(
		counters == [tracker.distance, tracker.gates_passed, tracker.laps, tracker.start_distance, tracker.next_gate],
		"정확한 원거리 위치 시드는 진행 거리·게이트·랩을 바꾸지 않는다"
	)
	for i in range(1, session.bodies.size()):
		session.teleport(i, 1000 + i * 5, -3.2 if i % 2 else 3.2)
		session.bodies[i].velocity = session.bodies[i].forward_direction() * 35
		session.bodies[i].grounded = true
	for frame in range(6):
		await tree.physics_frame
		session.teleport(0, 2200, 0)
		session.update_rivals(1.0 / 60)
	var before := 0
	for i in range(1, session.trackers.size()):
		before += session.trackers[i].full_searches
		check(
			session.trackers[i].has_previous_world and session.trackers[i].previous_trackable, "원거리 운반은 정확한 검색 힌트를 남긴다"
		)
	await tree.physics_frame
	session.teleport(0, 1040, 0)
	session.player_body.velocity = session.player_body.forward_direction() * 35
	session.player_body.grounded = true
	session.update_rivals(1.0 / 60)
	var after := 0
	var fast := 0
	for i in range(1, session.trackers.size()):
		after += session.trackers[i].full_searches
		fast += session.trackers[i].fast_updates
	check(after == before and fast == 15, "원거리15대가 동시에 근접해도 전체 투영 검색 대신 근방 검색을 사용한다")
	check(not session.trackers[0].has_previous_world, "플레이어 순간이동에는 원거리 상대의 신뢰 시드를 적용하지 않는다")
	for rival in race.rivals:
		rival.active = false
	var planned: RefCounted = race.rivals[0]
	planned.active = true
	session.teleport(0, 1000, 0)
	session.teleport(1, 1800, 0)
	session.bodies[1].velocity = session.bodies[1].forward_direction() * 35
	session.bodies[1].grounded = true
	planned.plan_time = .1
	planned.traffic_limit = 3
	var distance_before: float = planned.distance
	session.update_rivals(.02)
	check(planned.traffic_limit == 3 and planned.plan_time < .1, "먼 차량은 유효한 속도 계획을 재사용한다")
	check(planned.distance > distance_before, "계획을 재사용해도 원거리 차량은 매 틱 이동한다")
	planned.plan_time = .001
	session.update_rivals(.02)
	check(planned.traffic_limit == INF, "유효 시간이 끝나면 원거리 차량도 현재 앞차를 다시 판단한다")
	planned.traffic_limit = 3
	planned.plan_time = .1
	session.teleport(0, planned.distance - 20, 0)
	session.update_rivals(.02)
	check(planned.traffic_limit == INF, "150m 안으로 돌아온 차량은 오래된 원거리 계획을 즉시 갱신한다")
	planned.plan_time = .1
	session.teleport(1, 2200, 0)
	check(planned.plan_time == 0, "순간이동과 복구 뒤 원거리 계획을 남기지 않는다")
	race.free()
	await tree.process_frame
	print("16대 AI 판단 위상 / 복구 시간 초기화 / 운반 시드의 게이트 보존 / 동시 근접 전체 검색 방지: ", "PASS" if failures == 0 else "FAIL")
	return failures
