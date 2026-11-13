extends RefCounted
const Recovery = preload("res://scripts/race/road_recovery.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func quiet(race: Node3D) -> void:
	race.state = "racing"
	race.time_left = 300
	for rival in race.rivals:
		rival.active = false
	for body in race.world_race.bodies.slice(1):
		body.collision_layer = 0


func supported(tree: SceneTree, body: CharacterBody3D) -> bool:
	# 복구 탐색 헬퍼와 독립적으로 실제 차체 외곽의 노면을 측정한다.
	for x in [-1.05, 0.0, 1.05]:
		for z in [-2.15, 0.0, 2.15]:
			var feet: Vector3 = body.feet_position() + body.global_basis * Vector3(x, 0, z)
			var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .25, feet - Vector3.UP * .5, 1)
			var hit := tree.root.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit.collider.get_meta("recovery_unsafe", false):
				return false
	return true


func settle(tree: SceneTree, race: Node3D, label: String) -> void:
	var low := 0.0
	for frame in range(90):
		await tree.physics_frame
		race.step(1.0 / 60, 0, false, false, false)
		var body: CharacterBody3D = race.world_race.player_body
		var road: Vector3 = race.track.point(race.distance, race.lane)
		low = minf(low, body.feet_position().y - road.y)
	check(race.world_race.player_body.grounded and low > -.5, label + ": 복구 후 다시 추락하지 않고 접지한다")


func world_height(race: Node3D) -> float:
	return race.world_race.player_body.feet_position().y - race.track.point(race.distance, race.lane).y


func fall(tree: SceneTree, race: Node3D, d: float, lane: float, label: String) -> void:
	var world: Node3D = race.world_race
	world.teleport(0, d, lane, false)
	world.safe_distance = d
	world.safe_lane = lane
	world.player_body.position.y -= 9
	await tree.physics_frame
	var tracker: RefCounted = world.trackers[0]
	var laps: int = race.laps_completed
	var checkpoints: int = race.checkpoints
	var elapsed: float = race.elapsed
	world.update_recovery(.2, {"valid": false})
	check(supported(tree, world.player_body), label + ": 자동 낙하 복구는 차체 전체가 남은 도로 위에 놓여야 한다")
	check(
		is_equal_approx(race.speed * 3.6, 100) and is_equal_approx(world.player_body.velocity.length() * 3.6, 100),
		label + ": 시속100km로 달리며 복구한다"
	)
	for ahead in range(5, 101, 5):
		var at: Vector3 = race.track.point(race.distance + ahead, race.lane)
		var hit := Recovery.stable_hit(tree.root.get_world_3d().direct_space_state, at, Vector3.UP, 2)
		check(not hit.is_empty(), label + ": 전방100m에 남아 있는 노면이 있어야 한다")
	check(
		race.laps_completed == laps and race.checkpoints == checkpoints and race.elapsed == elapsed,
		label + ": 복구가 경기 진행을 변경하지 않는다"
	)
	check(is_equal_approx(tracker.distance, race.distance), label + ": 물리 차체와 진행도 복구 좌표가 일치한다")
	await settle(tree, race, label)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 4)
	race.restart()
	quiet(race)
	var world: Node3D = race.world_race
	var collapse: Node3D = race.track.active.collapse
	await tree.physics_frame
	var lane: float = race.track.active.surface_lane(5.5, 480)
	world.teleport(0, 480, lane, false)
	world.safe_distance = 480
	world.safe_lane = lane
	await tree.physics_frame
	check(world.recover_player() and supported(tree, world.player_body), "아직 멀쩡한 붕괴 예정 상판에도 복구하지 않는다")
	collapse.advance(4, 300)
	await tree.physics_frame
	await fall(tree, race, 480, lane, "트랙5 붕괴 상판")
	check(collapse.broken, "복구가 다리의 붕괴 상태를 초기화하면 안 된다")
	check(
		world.recover_body(1, 480, lane).size() > 0 and supported(tree, world.bodies[1]),
		"상대 차량도 붕괴 구간에서 실제 남은 노면으로 복구한다"
	)
	world.bodies[1].collision_layer = 0
	# 도로는 남아 있지만 앞부분이 걸칠 수 있는 파단 경계도 피한다.
	var edge: float = collapse.span.x - 1
	await fall(tree, race, edge, race.track.active.surface_lane(5.5, edge), "트랙5 붕괴 직전 가장자리")
	# 주변 차선 전체가 막히면24m보다 더 뒤의 남은 도로까지 탐색해야 한다.
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 2
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(100, 15, 120)
	barrier_shape.shape = barrier_box
	barrier.add_child(barrier_shape)
	tree.root.add_child(barrier)
	barrier.position = race.track.point(480) + Vector3.UP * 3
	barrier.rotation.y = race.track.heading(480)
	world.safe_distance = 480
	world.safe_lane = lane
	await tree.physics_frame
	check(
		world.recover_player() and race.distance < 440 and supported(tree, world.player_body),
		"전체 차선이 막힌 긴 구간에서는24m 한계를 넘어 뒤쪽 안전 도로를 찾는다"
	)
	barrier.queue_free()
	await tree.physics_frame
	for course in range(5):
		race.choose_mode("track", course)
		race.restart()
		quiet(race)
		await tree.physics_frame
		await fall(tree, race, 230, 0, "트랙%d" % (course + 1))
		if course == 4:
			world = race.world_race
			world.teleport(0, 230, 0, false)
			world.safe_distance = 230
			world.safe_lane = 0
			world.player_body.position.y -= 4
			world.player_body.velocity = Vector3.DOWN * 15
			race.camera.position = race.track.point(230) + Vector3.UP * 5
			race.camera.look_at(race.camera.position + Vector3.RIGHT)
			await tree.physics_frame
			world.update_recovery(.2, {"valid": false})
			check(
				supported(tree, world.player_body) and is_equal_approx(race.speed * 3.6, 100),
				"낙하선8m에 닿기 전에도 화면 밖으로 내려가면 시속100km로 복구한다"
			)
		if course == 0:
			for d in [
				race.track.active.bridge_lower_distance,
				race.track.active.bridge_upper_distance,
				race.track.active.underpass_span().x + 120
			]:
				await fall(tree, race, d, 0, "후지 교차 교량·지하도")
				check(absf(world_height(race)) < .5, "교량 교차점에서도 원래 도로 층으로 복구한다")
	race.choose_mode("tour")
	for stage in range(5):
		for node in range(stage + 1):
			race.track.reset(stage, node)
			race.world_race.trackers[0].configure(race.track)
			quiet(race)
			await tree.physics_frame
			await fall(tree, race, 230, 0, "투어%d/%d" % [stage, node])
			if [stage, node] in [[0, 0], [1, 1], [4, 4]]:
				await fall(tree, race, race.track.length - 100, 0, "투어 분기·최종 골 접근")
	# 중심 레이만 통과하는 좁은 받침은 차량을 지지하는 도로가 아니다.
	race.track.disable_world_queries(race.track)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.8, .2, .8)
	shape.shape = box
	ground.add_child(shape)
	tree.root.add_child(ground)
	ground.position = race.track.point(230) - Vector3.UP * .1
	await tree.physics_frame
	check(
		Recovery.candidate(race, race.world_race.player_body, 230, 0).is_empty(), "차체 중심 아래 작은 바닥만 남은 곳은 복구 후보에서 제외한다"
	)
	ground.queue_free()
	await tree.physics_frame
	world = race.world_race
	world.teleport(0, 80, 0, false)
	world.safe_distance = 80
	world.safe_lane = 0
	world.player_body.position.y -= 35
	var before: Transform3D = world.player_body.global_transform
	race.return_flash = 0
	world.update_recovery(.9, {"valid": false})
	check(
		world.player_body.global_transform == before and race.return_flash == 0,
		"안전한 노면이 없으면 자동 복구도 미검증 좌표로 이동하거나 성공 표시를 하지 않는다"
	)
	race.queue_free()
	await tree.process_frame
	print("붕괴 전·후·파단 가장자리 / 자동·수동·상대 복구 / 트랙5종·투어15지역 / 전체 지지·빈 노면 거부: ", "PASS" if failures == 0 else "FAIL")
	return failures
