extends RefCounted
const Crash = preload("res://scripts/physics/crash_state.gd")
var failures := 0


func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	for speed in [30.0, 299.9 / 3.6, 300.0 / 3.6, 84.0, 100.0]:
		for angle in [10.0, 29.9, 30.0, 30.1, 60.0, 90.0]:
			check(
				Crash.launches(speed, speed * sin(deg_to_rad(angle))) == (speed >= 300.0 / 3.6 and angle > 30),
				"300km/h·30도 이중 임계값"
			)
	check(Crash.launch_up(100) < 10, "최고속 충돌 비행의 상승속도 제한")
	var pool = preload("res://scripts/rendering/render_resources.gd")
	pool.acquire_owner()
	var road = preload("res://scripts/track/road_section.gd").new()
	road.stage = 1
	tree.root.add_child(road)
	# 긴 월드 곡선의 전역 검색 없이도 이전 거리에서 실제 횡단면을 추적해야 한다.
	for at in [100.0, 350.0, 800.0, 1400.0, road.length - 60]:
		for lane in [-6.0, 0.0, 6.0]:
			for hint in [at - 30, at + 30]:
				var projected: float = preload("res://scripts/race/tour_progress.gd").project_distance(
					road, road.point(at, lane), hint
				)
				check(absf(projected - at) < .1, "국소 투영은 굽은 도로·고저차·양 차선에서10cm 이내 거리를 복원한다")
	road.add_child(preload("res://scripts/physics/world_collision.gd").build(road))
	var cars: Array = road.features.filter(func(f): return f.kind == "car")
	check(cars.size() >= 2, "투어 승용차 장애물 배치")
	for feature in cars:
		check(absf(feature.lane) > 2.5 and feature.width <= 2.1, "승용차는 한 차로만 차지하고 중앙 통과 공간을 남긴다")
	var hills := 0
	for stage in range(5):
		for node in range(stage + 1):
			var section = preload("res://scripts/track/road_section.gd").new(Vector3.ZERO, -PI / 2, stage, node)
			hills += section.hill_spans().size()
			section.free()
	check(hills >= 5, "여러 투어 지역에 큰 추가 능선이 있어야 한다")
	var traffic: Node3D = road.get_children().filter(func(node): return node.get_meta("parked_car", false))[0]
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.current = true
	var direction: Vector3 = traffic.forward_direction()
	camera.position = traffic.position - direction * 60 + Vector3.UP * 8
	camera.look_at(traffic.position - direction * 200)
	var unseen: Vector3 = traffic.position
	for frame in range(4):
		await tree.physics_frame
	check(not traffic.activated and traffic.position.distance_to(unseen) < .01, "보이지 않는 교통 차량은 출발하지 않는다")
	camera.look_at(traffic.position)
	for frame in range(25):
		await tree.physics_frame
	check(traffic.activated and traffic.position.distance_to(unseen) > .2, "시야에 들어온 교통 차량이 실제 차체로 움직인다")
	check(
		(
			traffic.visual.global_position.distance_to(
				traffic.feet_position() - traffic.surface_normal * traffic.visual.ride_offset
			)
			< .02
		),
		"움직이는 교통 차량의 시각 모델은 물리 중심보다 타이어 접지면에 맞춰 떠 보이지 않아야 한다"
	)
	var motor = preload("res://scripts/physics/world_car.gd").new()
	motor.configure(preload("res://scripts/vehicles/vehicle_catalog.gd").spec(0))
	tree.root.add_child(motor)
	var hit_car := false
	var feature: Dictionary = cars[0]
	var forward: Vector3 = (road.point(feature.distance + 1) - road.point(feature.distance - 1)).normalized()
	motor.reset_pose(road.point(feature.distance - 7, feature.lane), forward)
	motor.velocity = forward * 35
	for frame in range(40):
		await tree.physics_frame
		var hits: Array = motor.advance(1.0 / 60, 0, 35, false)
		for hit in hits:
			if hit.collider.get_meta("parked_car", false):
				hit_car = true
				check(
					(
						not hit.severe
						and motor.velocity.dot(forward) > 10
						and motor.velocity.length() < 35
						and hit.collider.velocity.length() > 1
					),
					"실제 승용차 접촉은 감속·반동하고 벽 비행으로 분류하지 않는다"
				)
		if hit_car:
			break
	check(hit_car, "실제 투어 승용차 충돌체와 접촉해야 한다")
	camera.queue_free()
	motor.queue_free()
	road.queue_free()
	await tree.process_frame
	if pool.release_owner():
		preload("res://scripts/environment/regional_props_3d.gd").clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
		preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
	print("충돌 이중 임계값 / 투어 승용차 실제 반동 / 추가 고저차: ", "PASS" if failures == 0 else "FAIL")
	return failures
