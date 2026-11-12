extends RefCounted
const Power = preload("res://scripts/physics/drive_power.gd")
const Probe = preload("res://tests/corner_feel_checks.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var helper := Probe.new()
	var race := helper.make_race(tree)
	race.choose_mode("track", 0)
	var floor := helper.physical_floor(tree)
	await tree.physics_frame
	await tree.physics_frame
	var rows := []
	for vehicle in range(4):
		race.open_garage()
		race.select_vehicle(vehicle)
		var entry: float = race.vehicle.boost_speed
		var held: Dictionary = await helper.world_trial(tree, race, 0, true, false, false, false, entry)
		var released: Dictionary = await helper.world_trial(tree, race, 0, false, false, false, false, entry)
		var braking: Dictionary = await helper.world_trial(tree, race, 0, true, true, false, false, entry)
		check(
			held.exit_mps >= released.exit_mps - .05 and held.exit_mps < entry, "부스트 종료 후 가속 유지는 자연 감속보다 강한 제동을 만들지 않는다"
		)
		check(braking.exit_mps < held.exit_mps - 5, "관성을 보존해도 실제 브레이크는 충분히 감속한다")
		check(held.wall_hits == 0 and held.offroad == 0 and not held.airborne, "관성 비교는 접지한 평지에서 수행한다")
		var corner: Dictionary = await helper.world_trial(tree, race, .35, true, false, false, false, entry)
		check(corner.exit_mps < held.exit_mps - 2, "초과 속도의 급조향에서도 실제 타이어 저항이 속도를 줄인다")
		race.world_race.teleport(0, 400, race.track.half_width(400) + 3)
		race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * entry
		race.speed = entry
		for tick in range(33):
			await tree.physics_frame
			race.step(1.0 / 60, 0, false, true, false)
		check(race.offroad_amount > .9 and race.speed < held.exit_mps - 4, "실제 노면 이탈도 관성으로 지름길 이득을 만들지 않는다")
		rows.append({"vehicle": race.vehicle.id, "held": held, "released": released, "braking": braking})
	race.open_garage()
	race.select_vehicle(0)
	for curve in [0.0, .01]:
		helper.fixture_curve(race, curve, 0, Vector3(8000, 100, 8000))
		race.track.curvature_cache = preload("res://scripts/track/circuit_curvature.gd").new(
			race.track.active.curve, race.track.length
		)
		for rival in race.rivals:
			rival.active = false
		var rival = race.rivals[0]
		rival.active = true
		race.world_race.teleport(0, 90 if curve == 0 else 200, -3 if curve > 0 else 0)
		race.world_race.player_body.velocity = race.world_race.player_body.forward_direction() * 20
		race.world_race.teleport(1, 80)
		var cpu: CharacterBody3D = race.world_race.bodies[1]
		cpu.velocity = cpu.forward_direction() * 80
		cpu.grounded = true
		# 중거리 상대는 두 틱에 한 번 갱신하므로 두 위상을 모두 관측한다.
		for tick in range(2):
			await tree.physics_frame
			race.world_race.update_rivals(1.0 / 60)
		check(
			cpu.velocity.length() < 79.8, "상대 차량은 관성 중에도 앞차·실제 곡률에 제동한다: 곡률=%s 속도=%s" % [curve, cpu.velocity.length()]
		)
	var speed := 100.0
	for tick in range(3600):
		speed = Power.target(speed, 72, 16, 1.0 / 60, true)
	check(is_equal_approx(speed, 72), "초과 속도를 무한 유지하거나 원래 상한 아래로 떨어뜨리지 않는다")
	check(Power.target(90, 50, 20, .5, true, 1) < Power.target(90, 50, 20, .5, true), "이탈 노면의 항력은 부스트 지름길을 억제한다")
	FileAccess.open("res://build/reports/momentum-metrics.json", FileAccess.WRITE).store_string(
		JSON.stringify(rows, "  ")
	)
	race.free()
	floor.free()
	await tree.process_frame
	print("부스트 종료 관성 / 가속·해제·제동4차종 / 초과 속도 수렴·이탈 항력: ", "PASS" if failures == 0 else "FAIL")
	return failures
