extends RefCounted
const Probe = preload("res://tests/corner_feel_checks.gd")
const Nitro = preload("res://scripts/race/nitro_system.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var helper := Probe.new()
	var race := helper.make_race(tree)
	var floor := helper.physical_floor(tree)
	await tree.physics_frame
	var speeds: Array[float] = []
	for course in range(5):
		race.choose_mode("track", course)
		helper.fixture_curve(race, 0, 0, Vector3(8000, 100, 8400))
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		race.world_race.teleport(0, 400)
		await tree.physics_frame
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, false, false)
		var body: CharacterBody3D = race.world_race.player_body
		body.velocity = body.forward_direction() * 40
		race.speed = 40
		race.drift_latched = true
		race.steer = .25
		body.steering = .25
		for tick in range(33):
			await tree.physics_frame
			race.step(1.0 / 60, .25, false, true, false)
		speeds.append(race.speed)
		check(
			body.coast_profile and race.drifting and race.wall_hits == 0 and race.offroad_amount == 0,
			"모든 트랙이 같은 접지 드리프트를 사용한다"
		)
	check(speeds.max() - speeds.min() < .1, "같은 차·시험 노면·입력의 드리프트 결과는 코스 번호와 무관하다")
	race.vehicle = preload("res://scripts/vehicles/vehicle_catalog.gd").spec(1)
	race.reset_nitro()
	race.speed = 50
	race.throttling = true
	race.braking = false
	race.impact = 0
	race.drifting = true
	Nitro.update(race, .016, true, false)
	Nitro.update(race, .1, false, false)
	check(race.nitro_charges == 3, "드리프트 중 예약은 샷을 먼저 소비하지 않는다")
	race.drifting = false
	Nitro.update(race, .016, false, false)
	check(race.nitro_active and race.nitro_charges == 2, "짧은 탈출 연결은 한 발만 발사한다")
	var remaining: float = race.nitro_burst_left
	race.drifting = true
	Nitro.update(race, .1, false, false)
	check(race.nitro_burst_left == remaining and not race.nitro_active, "짧은 드리프트 전환에서는 남은 샷 시간을 보존한다")
	race.drifting = false
	Nitro.update(race, .016, false, false)
	check(race.nitro_active and race.nitro_charges == 2, "샷 재개는 추가 횟수를 소비하지 않는다")
	race.drifting = true
	Nitro.update(race, .2, false, false)
	check(race.nitro_burst_left == 0, "샷별 누적 유예 예산을 넘으면 취소해 무한 연장을 막는다")
	for index in [1, 2]:
		race.vehicle = preload("res://scripts/vehicles/vehicle_catalog.gd").spec(index)
		race.reset_nitro()
		race.drifting = true
		Nitro.update(race, .016, index == 1, index == 2)
		Nitro.update(race, .23, false, false)
		race.drifting = false
		Nitro.update(race, .016, false, false)
		check(race.nitro_charges == race.vehicle.charges and not race.nitro_active, "놓은 샷·셀 탭의 유예가 끝나면 나중에 자동 발사하지 않는다")
		race.reset_nitro()
		race.drifting = true
		Nitro.update(race, .016, index == 1, index == 2)
		race.drifting = false
		Nitro.update(race, .016, false, false)
		check(race.nitro_active and race.nitro_charges == race.vehicle.charges - 1, "하이브리드 셀도 탈출 연결에서 한 번만 발사한다")
	race.drift_latched = false
	race.drift_previous_input = false
	race.steer = .25
	race.world_race.player_body.grounded = false
	race.world_race.update_drift(.016, true, false, true)
	check(not race.drifting and race.drift_pending > 0, "공중에서 미리 누른 드리프트 입력은 착지까지 대기한다")
	race.world_race.player_body.grounded = true
	race.world_race.update_drift(.016, false, false, true)
	check(race.drifting, "짧은 착지 후 드리프트 입력을 다시 누를 필요 없이 연결한다")
	# 지속 제동은 드리프트 예약이 아니고 짧은 탭과 깊은 조향만 허용한다.
	race.drift_latched = false
	race.previous_brake = false
	race.steer = .5
	for tick in range(30):
		race.world_race.update_drift(1.0 / 60, false, true, true)
	race.world_race.update_drift(.016, false, false, true)
	check(not race.drifting, "지속 코너 제동을 해제해도 드리프트로 바뀌지 않는다")
	race.world_race.update_drift(.016, false, true, true)
	race.world_race.update_drift(.016, false, false, true)
	check(race.drifting, "짧은 제동 탭과 깊은 조향은 드리프트로 연결된다")
	FileAccess.open("res://build/reports/drift-flow-metrics.json", FileAccess.WRITE).store_string(
		JSON.stringify(speeds)
	)
	race.free()
	floor.free()
	await tree.process_frame
	print("5트랙 드리프트 일관성 / 샷 입력 버퍼·누적 대기 제한: ", "PASS" if failures == 0 else "FAIL")
	return failures
