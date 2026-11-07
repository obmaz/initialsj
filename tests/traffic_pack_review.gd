extends SceneTree
const Report = preload("res://tests/report.gd")
const Contact = preload("res://scripts/car_contact.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",1)
	var report := []
	var failures := 0
	for vehicle in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(vehicle)
		race.restart()
		race.state = "racing"
		race.distance = 1500
		race.speed = 0
		race.lane = 7
		var overlaps := 0
		var depth := 0.0
		for frame in range(9000):
			race.brain.tick(race,1.0/60)
			for a in range(7):
				for b in range(a+1,7):
					var ra: Dictionary = race.rivals[a]
					var rb: Dictionary = race.rivals[b]
					var gap: float = race.relative_gap(rb.distance,ra.distance)
					var contact := Contact.overlap(gap,rb.lane-ra.lane,ra.visual_yaw,rb.visual_yaw)
					if contact.is_empty(): continue
					overlaps += 1
					depth = maxf(depth,contact.depth)
		var entry := {"vehicle":race.vehicle.id,"simulation_seconds":150,"pair_checks":189000,"overlap_frames":overlaps,"worst_depth_m":depth}
		print(JSON.stringify(entry))
		report.append(entry)
		if overlaps > 0:
			push_error("CPU pack must keep non-overlapping footprints during sustained circuit driving")
			failures += 1
		await process_frame
	FileAccess.open(Report.path("traffic-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"vehicles":report,"failures":failures},"\t")+"\n")
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
