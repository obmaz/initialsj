extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.choose_mode("track", 2)
	var expected := [24.0, 21.5, 19.0, 26.0]
	for choice in range(4):
		race.open_garage()
		race.select_vehicle(choice)
		check(Catalog.spec(choice).brake == expected[choice], "차종별 브레이크 감속을 정확히 절반으로 적용한다")
		for side in [-1.0, 1.0]:
			race.restart()
			race.state = "racing"
			for rival in race.rivals:
				rival.active = false
			var d := 1480.0
			var edge: float = race.track.half_width(d) + race.track.active.rail_setback(d, side)
			var road: Vector3 = (race.track.point(d + 2) - race.track.point(d - 2)).normalized()
			var right: Vector3 = (race.track.point(d, 1) - race.track.point(d)).normalized()
			var body: CharacterBody3D = race.world_race.player_body
			race.world_race.teleport(0, d, side * (edge - 1.35))
			body.reset_pose(
				race.track.point(d, side * (edge - 1.35)),
				(road + right * side * .28).normalized(),
				race.world_race.road_up(d)
			)
			body.velocity = body.forward_direction() * 3.6
			race.speed = 3.6
			var opposite_clear := true
			for frame in range(240):
				await tree.physics_frame
				race.step(1.0 / 60, 0, false, true, false)
				opposite_clear = opposite_clear and race.lane * side > -race.track.half_width(race.distance) + 1.2
			check(
				race.distance > d + 35 and race.speed > 12 and race.personal_run.recoveries == 0,
				"항만 저속 끼임에서 리셋 없이 전진한다: %d/%s" % [choice, side]
			)
			check(opposite_clear and not race.crash.active, "반대편 레일로 튕기거나 비행하지 않고 탈출한다")
		# 평탄한 직선에서1초간 실제 브레이크 입력의 감속량을 확인한다.
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		race.world_race.teleport(0, 1490, 0)
		var body: CharacterBody3D = race.world_race.player_body
		body.velocity = body.forward_direction() * 40
		race.speed = 40
		for frame in range(60):
			await tree.physics_frame
			race.step(1.0 / 60, 0, false, true, true)
		check(absf((40 - race.speed) - expected[choice]) < 2, "실제 주행의 제동 감속도 절반으로 반영한다: %d" % choice)
	race.free()
	await tree.process_frame
	print("항만4차종·양측 저속 레일 탈출 / 반대편 충돌 방지 / 실제 절반 제동: ", "PASS" if failures == 0 else "FAIL")
	return failures
