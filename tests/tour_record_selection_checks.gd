extends RefCounted
var failures := 0


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.state = "racing"
	race.track.reset(3, 0)
	race.world_race.trackers[0].configure(race.track)
	race.record_cache_loaded = true
	race.record_store = ConfigFile.new()
	var left_key = "tour_routes_v3_" + str(race.vehicle.id) + "_LLLL"
	var right_key = "tour_routes_v3_" + str(race.vehicle.id) + "_LLLR"
	race.record_store.set_value(race.RECORD_GROUP, left_key, 111.0)
	race.record_store.set_value(race.RECORD_GROUP, right_key, 222.0)
	race.distance = race.track.length + 80
	race.lane = -1
	race.advance_route()
	var right_road = race.track.sibling
	var world = race.world_race
	var body = world.player_body
	var target = right_road.point(100)
	var facing = right_road.point(102) - right_road.point(98)
	world.trackers[0].configure(race.track)
	world.trackers[0].reposition(100)
	body.reset_pose(target + Vector3.UP * .04, facing)
	body.velocity = facing.normalized() * 35
	body.grounded = true
	race.distance = 100
	race.speed = 35
	race.time_left = 100
	await tree.physics_frame
	race.step(1.0 / 60, 0, false, true, false)
	if race.record_key() != race.loaded_record_key or race.best_time != 222.0:
		failures += 1
		push_error("투어 경로 재선택 즉시 해당 경로의 BEST 기록을 조회한다")
	race.free()
	await tree.process_frame
	print("투어 재선택 기록: ", "PASS" if failures == 0 else "FAIL")
	return failures
