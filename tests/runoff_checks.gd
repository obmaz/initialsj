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
	for course in range(5):
		race.choose_mode("track", course)
		var road: Node3D = race.track.active
		var maximum := 0.0
		var minimum := INF
		var distance := 0.0
		var side := 1.0
		var wide := 0
		for i in range(240):
			var d: float = road.length * i / 240
			for bank in [-1.0, 1.0]:
				var offset: float = road.rail_setback(d, bank)
				minimum = minf(minimum, offset)
				wide += 1 if offset > 4 else 0
				if offset > maximum and not road.on_bridge(d) and not road.in_tunnel(d):
					maximum = offset
					distance = d
					side = bank
		check(maximum - minimum > 3 and wide > 0 and wide < 240, "트랙%d는 밀착 경계와 일부 넓은 여유 구간을 함께 갖는다" % (course + 1))
		await tree.physics_frame
		var space := tree.root.get_world_3d().direct_space_state
		var lane: float = side * (road.half_width(distance) + maximum * .5)
		var p: Vector3 = road.point(distance, lane)
		var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP, 1))
		check(not floor.is_empty() and absf(floor.position.y - p.y) < .2, "넓어진 흙·잔디 여유 구간에도 실제 접지 노면이 있어야 한다")
		var start: Vector3 = road.point(distance, side * (road.half_width(distance) + maximum - 1)) + Vector3.UP * .7
		var end: Vector3 = road.point(distance, side * (road.half_width(distance) + maximum + 1.2)) + Vector3.UP * .7
		check(
			not space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 2)).is_empty(),
			"가드 충돌면은 갓길 바깥의 보이는 위치와 일치한다"
		)
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		race.world_race.teleport(0, distance, lane)
		var car: CharacterBody3D = race.world_race.player_body
		car.velocity = car.forward_direction() * 20
		race.speed = 20
		var hits: int = race.wall_hits
		for frame in range(20):
			await tree.physics_frame
			race.step(1.0 / 60, 0, false, false, false)
		check(car.grounded and race.wall_hits == hits and car.velocity.length() > 1, "차량은 곧바로 가드에 부딪히지 않고 여유 구간을 주행한다")
	race.queue_free()
	await tree.process_frame
	print("트랙5종 선택적 여유 / 실제 바닥·가드 일치 / 차량 접지·재진입 공간: ", "PASS" if failures == 0 else "FAIL")
	return failures
