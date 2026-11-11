extends RefCounted
const Drive = preload("res://tests/tour_world_checks.gd")
const Section = preload("res://scripts/track/road_section.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	# 모든 테마의 보이는 노면과 실제 접지 높이를 비교한다.
	for stage in range(5):
		for node in range(stage + 1):
			var road := Section.new(Vector3(0, 6, 0), -PI / 2, stage, node)
			tree.root.add_child(road)
			road.add_child(preload("res://scripts/physics/world_collision.gd").build(road))
			await tree.physics_frame
			await tree.physics_frame
			for sample in range(80):
				var d: float = 30 + (road.length - 60) * sample / 79
				var on_device := false
				for feature in road.features:
					if (
						feature.kind in ["ramp", "skyway"]
						and absf(d - float(feature.distance)) < float(feature.length) * 0.5 + 3
						and absf(float(feature.lane)) < float(feature.width) * 0.5 + 1
					):
						on_device = true
				if on_device:
					continue
				var point: Vector3 = road.point(d, 0)
				var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.35, point - Vector3.UP * 0.35, 1)
				var floor: Dictionary = tree.root.get_world_3d().direct_space_state.intersect_ray(query)
				check(
					not floor.is_empty() and absf(floor.position.y - point.y) < 0.15,
					"모든 투어 테마의 실제 노면 높이는 보이는 도로와 일치해야 한다: %d/%d @%.1f" % [stage, node, d]
				)
			for truck in road.features.filter(func(f): return f.kind == "truck"):
				var front: Vector3 = road.point(truck.distance - truck.length * 0.5 - 2, truck.lane) + Vector3.UP * 1.8
				var middle: Vector3 = road.point(truck.distance, truck.lane) + Vector3.UP * 1.8
				var hit: Dictionary = tree.root.get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(front, middle, 4)
				)
				check(
					not hit.is_empty() and hit.collider.get_meta("parked_truck", false),
					"모든 트럭은 밀려날 수 있는 실제 교통 차체를 가져야 한다: %s" % truck.id
				)
			road.queue_free()
			await tree.process_frame
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var driver := Drive.new()
	for region in [[0, 0], [1, 1], [4, 0]]:
		race.track.reset(region[0], region[1])
		race.state = "racing"
		race.time_left = 200
		race.initialize_traffic()
		race.world_race.reset()
		await tree.physics_frame
		var road: Node3D = race.track.active
		var ramps: Array = road.features.filter(func(f): return f.kind == "ramp")
		for ramp in ramps:
			for speed in [65.0, 95.0]:
				race.crash.reset()
				race.surface.reset()
				driver.set_car(race, ramp.distance - ramp.length * 0.5 - 12, ramp.lane, speed)
				var launched := false
				var landed := false
				var peak := 0.0
				for frame in range(240):
					race.step(1.0 / 60, driver.drive_axis(race, ramp.lane), false, false, false)
					peak = maxf(peak, race.air.height)
					if race.distance > ramp.distance and not race.world_race.player_body.grounded:
						launched = true
					if launched and race.world_race.player_body.grounded:
						landed = true
						break
				check(
					launched and landed and peak > 0.15 and race.wall_hits == 0,
					"투어 점프대는 실제 차체를 발사하고 안전하게 착지시켜야 한다: %s %.0f 높이 %.2f" % [ramp.id, speed, peak]
				)
		# 고가 통로 위와 아래의 접촉 높이는 실제로 분리되어야 한다.
		for deck in road.features.filter(func(f): return f.kind == "skyway"):
			var point: Vector3 = road.point(deck.distance, deck.lane)
			var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
			var upper: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(point + Vector3.UP * 12, point + Vector3.UP * 3, 1)
			)
			var lower: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1)
			)
			check(
				not upper.is_empty() and not lower.is_empty() and upper.position.y - lower.position.y > 4,
				"상부 통로와 아래 도로는 서로 다른 실제 바닥이어야 한다"
			)
	race.queue_free()
	await tree.process_frame
	print("투어 15테마 실제 접지 / 고가 통로 / 실제 점프 착지: ", "PASS" if failures == 0 else "FAIL")
	return failures
