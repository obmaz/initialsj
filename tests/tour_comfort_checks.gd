extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Features = preload("res://scripts/track/road_features.gd")
const Library = preload("res://scripts/track/route_library.gd")
const Drive = preload("res://tests/tour_world_checks.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var tunnels := 0
	var skyways := 0
	for stage in range(5):
		for route in range(stage + 1):
			var span := Library.tunnel_span(stage, route)
			if span.y > span.x:
				tunnels += 1
				check(span.y - span.x <= 400, "투어 터널은400m를 넘지 않아야 한다")
			var road := Section.new(Vector3(0, 6, 0), -PI / 2, stage, route)
			road.features = Features.layout(road)
			for deck in road.features.filter(func(f): return f.kind == "skyway"):
				skyways += 1
				var start: float = deck.distance - deck.length * .5
				check(deck.width >= 8 and deck.length >= 280, "고가 상판은 넓은 진입과 주행 공간을 확보해야 한다")
				for at in [start, deck.distance, start + deck.length]:
					check(road.half_width(at) >= 11.0, "고가 진입·상판·출구 주변의 도로도 함께 넓어야 한다")
				check(Features.skyway_height(deck, start + 1) < .015, "고가 진입 경사는 시작점에서 갑자기 꺾이면 안 된다")
			road.free()
	check(tunnels <= 6 and skyways == 4, "터널은 일부 지역만 사용하고 도시·서울·네온·항만의 고가를 유지해야 한다")
	for path in range(16):
		var route := 0
		var covered := 0.0
		var count := 0
		for stage in range(5):
			if stage > 0:
				route += (path >> (stage - 1)) & 1
			var span := Library.tunnel_span(stage, route)
			if span.y > span.x:
				count += 1
				covered += span.y - span.x
		check(count <= 3 and covered < 1000, "어떤 투어 경로도 터널만 반복되거나1km 넘게 시야를 가리면 안 된다")
	for pair in [[1, 1], [3, 1], [3, 3]]:
		var road := Section.new(Vector3(0, 6, 0), -PI / 2, pair[0], pair[1])
		tree.root.add_child(road)
		check(
			road.scenery.building_manifest.size() >= (45 if pair[0] == 3 and pair[1] == 1 else 70),
			"도시 배경은 여러 줄의 충분한 건물 군집을 가져야 한다"
		)
		if road.scenery.theme == "neon":
			var counts := {}
			for p in road.scenery.roadside_art.models.placements:
				counts[p.kind] = counts.get(p.kind, 0) + 1
			check(
				counts.get("neon_arcade", 0) >= 10 and counts.get("neon_pylon", 0) >= 20,
				"네온 지역은 실제 아케이드·전자상가와 입체 네온 간판을 충분히 배치해야 한다"
			)
		road.queue_free()
		await tree.process_frame
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("tour")
	race.track.reset(1, 1)
	race.initialize_traffic()
	race.world_race.reset()
	await tree.physics_frame
	var deck: Dictionary = race.track.active.features.filter(func(f): return f.kind == "skyway")[0]
	var driver := Drive.new()
	for choice in range(4):
		race.state = "ready"
		race.select_vehicle(choice)
		for offset in [-1.5, 1.5]:
			race.state = "racing"
			race.time_left = 200
			race.crash.reset()
			race.surface.reset()
			race.wall_hits = 0
			for rival in race.rivals:
				rival.active = false
			var lane: float = deck.lane + offset
			driver.set_car(race, deck.distance - deck.length * .5 - 45, lane, 35)
			var reached := false
			for frame in range(420):
				race.step(1.0 / 60, driver.drive_axis(race, lane), false, true, false)
				var height: float = race.world_race.player_body.feet_position().y - race.track.point(race.distance).y
				if race.distance >= deck.distance - 35 and height > 5.2 and race.world_race.player_body.grounded:
					reached = true
					break
				if race.distance > deck.distance + 25:
					break
			check(
				reached and race.wall_hits == 0,
				"모든 차량이 중앙에서 벗어난 진입 차로에서도 고가에 올라 접지 주행해야 한다: %s / %.1f" % [race.vehicle.id, offset]
			)
	race.queue_free()
	await tree.process_frame
	print("짧은 선택형 터널 / 도시 건물 군집 / GLB 네온 거리 / 넓고 완만한 고가4차종 진입: ", "PASS" if failures == 0 else "FAIL")
	return failures
