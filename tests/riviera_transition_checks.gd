extends RefCounted
const Profile = preload("res://scripts/track/riviera_profile.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.save_records = false
	race.set_physics_process(false)
	race.choose_mode("track", 3)
	var road: Node3D = race.track.active
	var scenery: Node3D = road.scenery
	for span in Profile.CANYONS:
		for lane in [-60.0, -120.0, -200.0, -350.0]:
			var previous: Vector3 = scenery.terrain_point(span.x - 210, lane)
			for d in range(int(span.x - 205), int(span.y + 210), 5):
				var p: Vector3 = scenery.terrain_point(d, lane)
				check(absf(p.y - previous.y) < 6, "협곡 입구·출구의 해안이 급격한 수직 단차 없이 이어져야 한다")
				previous = p
		check(
			scenery.terrain_point((span.x + span.y) * .5, -410).y < scenery.water.position.y,
			"협곡 바깥 해안 경사는 실제 수면 아래로 연결되어야 한다"
		)
	check(
		road.half_width(1100) < 10 and road.half_width(2400) < 10.1 and road.half_width(1600) > 12,
		"협곡 두 곳은 좁아지고 마을 쪽은 다시 넓어져야 한다"
	)
	for d in range(0, int(road.length), 3):
		check(absf(road.half_width(d + 3) - road.half_width(d)) < .15, "폭 축소와 복귀는 가드레일을 따라 완만하게 이어져야 한다")
	check(Profile.warning(700) != "" and Profile.warning(1600) == "", "폭 축소 전에는 미리 알리고 통과 후에는 해제해야 한다")
	check(road.features.filter(func(f): return f.kind == "boost").size() >= 5, "트랙4에도 여러 가속 패드가 있어야 한다")
	check(road.features.filter(func(f): return f.kind == "boost_lane").size() == 2, "유지형 부스트 차로 두 곳이 있어야 한다")
	var ramps: Array = road.features.filter(func(f): return f.kind == "ramp")
	check(ramps.size() == 2, "선택해서 탈 수 있는 점프대 두 곳이 있어야 한다")
	await tree.physics_frame
	await tree.physics_frame
	# 렌더링 지형을 함께 굽는 실제 바닥에 해안 반도의 유령 노면이 생기면 안 된다.
	for i in range(180):
		var d: float = road.length * i / 180
		var p: Vector3 = road.point(d)
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 100, p - Vector3.UP * 3, 1)
		var hit: Dictionary = road.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - p.y) < .2, "확장한 해안 지형이 실제 차도 위를 덮으면 안 된다")
	for ramp in ramps:
		for speed in [65.0, 90.0]:
			race.restart()
			race.state = "racing"
			for rival in race.rivals:
				rival.active = false
			race.world_race.teleport(0, ramp.distance - 35, ramp.lane)
			var body: CharacterBody3D = race.world_race.player_body
			body.velocity = body.forward_direction() * speed
			race.speed = speed
			var flew := false
			var landed := false
			for frame in range(210):
				var forward: Vector3 = body.forward_direction()
				var right := Vector3(-forward.z, 0, forward.x).normalized()
				var aim: Vector3 = road.point(race.distance + 25, ramp.lane) - body.feet_position()
				var angle := atan2(aim.dot(right), aim.dot(forward))
				var wheel: float = (
					(.46 + race.vehicle.handling * .007)
					/ (1 + race.speed * .035)
					* race.world_race.WorldCar.steering_scale(race.speed)
				)
				await tree.physics_frame
				race.step(1.0 / 60, clampf(atan(5.4 * sin(angle) / 25) / wheel, -1, 1), false, false, false)
				if (
					frame > 8
					and not body.grounded
					and body.feet_position().y - road.point(race.distance, race.lane).y > .4
				):
					flew = true
				if flew and body.grounded and race.distance > ramp.distance + 20:
					landed = true
					break
			check(flew and landed and race.wall_hits == 0, "새 해안 점프대는 실제 차체가 이륙·착지하고 측면 우회로를 남겨야 한다")
	race.queue_free()
	await tree.process_frame
	print("해안·협곡 연속 지형 / 실제 폭 축소 / 패드·차로 / 점프 착지: ", "PASS" if failures == 0 else "FAIL")
	return failures
