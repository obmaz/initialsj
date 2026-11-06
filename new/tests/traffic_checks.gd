extends RefCounted
const Contact = preload("res://scripts/car_contact.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var report := []
	for mode in ["tour","track"]:
		race.choose_mode(mode)
		race.distance = 80 if mode == "tour" else 1200
		race.lane = -6
		for scenario in ["stopped_queue","merge_blocked","meeting_merge","lapped_queue"]:
			if scenario == "lapped_queue" and mode != "track": continue
			for rival in race.rivals: rival.active = false
			var a: Dictionary = race.rivals[0]
			var b: Dictionary = race.rivals[1]
			for rival in [a,b]:
				rival.active = true
				rival.surface.reset()
				rival.decision = 100.0
				rival.visual_yaw = 0.0
				rival.speed = 35.0
				rival.pace = 35.0
				rival.lane = 0.0
				rival.target_lane = 0.0
			a.distance = 400.0
			b.distance = 400.0
			if scenario.ends_with("queue"):
				a.speed = 0.0; a.pace = 0.0
				b.distance = 320.0; b.speed = 80.0; b.pace = 80.0
				if scenario == "lapped_queue": a.distance += race.track.length
			elif scenario == "merge_blocked": b.lane = 4.0
			else: a.lane = -3.0; b.lane = 3.0
			var overlaps := 0
			var minimum_gap := INF
			for frame in range(180):
				race.brain.tick(race,1.0/60)
				var gap: float = race.relative_gap(b.distance,a.distance)
				minimum_gap = minf(minimum_gap,absf(gap))
				if not Contact.overlap(gap,b.lane-a.lane,a.visual_yaw,b.visual_yaw).is_empty(): overlaps += 1
			check(overlaps == 0,"CPU bodies must not overlap in "+mode+" / "+scenario)
			if scenario.ends_with("queue"):
				check(b.speed < 0.1 and minimum_gap > 5,"CPU must stop at a safe following distance, including lapped traffic")
			else: check(b.distance > 480 and b.speed > 30,"Safe merges must retain progress instead of freezing traffic")
			report.append({"mode":mode,"scenario":scenario,"overlap_frames":overlaps,"minimum_gap":snappedf(minimum_gap,0.01)})
		for rival in race.rivals: rival.active = false
		var stopped: Dictionary = race.rivals[0]
		stopped.active = true
		stopped.distance = 300.0
		stopped.lane = 0.0
		stopped.target_lane = 4.0
		stopped.speed = 0.0
		stopped.pace = 0.0
		stopped.decision = 100.0
		stopped.surface.reset()
		for frame in range(30): race.brain.tick(race,1.0/60)
		check(absf(stopped.lane) < 0.001,"A stationary CPU car must not slide sideways to change lanes")
	print("Traffic safety checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	print(JSON.stringify(report))
	race.queue_free()
	await tree.process_frame
	return failures
