extends SceneTree
# Deterministic tactics comparison, not a human playtest.
var failures := 0
var report := {}
func _initialize():
	call_deferred("run")
func run():
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for strategy in ["no_boost", "passing_and_boost"]:
		race.restart()
		race.state = "racing"
		var wanted_lane := -3.2
		var boost_latched := false
		for i in range(10800):
			if strategy != "no_boost" and i % 18 == 0:
				var best := INF
				for candidate in [-5.4, -2.7, 0, 2.7, 5.4]:
					var cost: float = absf(candidate - race.lane) * 0.15
					for r in race.rivals:
						var gap: float = wrapf(r.distance - race.distance, -race.track.length / 2, race.track.length / 2)
						if absf(candidate - r.lane) < 2.3 and gap > -10 and gap < 42:
							cost += 42 - gap
						if absf(gap) < 7 and r.lane > minf(candidate, race.lane) - 1.9 and r.lane < maxf(candidate, race.lane) + 1.9:
							cost += 120
					if cost < best:
						best = cost
						wanted_lane = candidate
			var bend: float = wrapf(race.track.heading(race.distance + 55) - race.track.heading(race.distance), -PI, PI)
			var rate: float = wrapf(race.track.heading(race.distance + 16) - race.track.heading(race.distance), -PI, PI) / 16
			var correction: float = clampf(((wanted_lane - race.lane) * 1.5 - rate * race.speed * race.speed * 0.04) / 7.6, -1, 1)
			boost_latched = strategy != "no_boost" and absf(bend) < 0.38 and race.speed > 50 and race.nitro > (2 if boost_latched else 40)
			race.step(1.0 / 60, correction, false, boost_latched, false)
			race.place_cars()
			race.update_camera(1.0 / 60)
			if race.state == "finished":
				break
		report[strategy] = {"rank": race.rank_position(), "seconds": snappedf(race.elapsed, 0.01), "finished": race.state == "finished"}
	if not report.passing_and_boost.finished or report.passing_and_boost.rank > 3 or report.passing_and_boost.rank >= report.no_boost.rank:
		push_error("Clean passing and deliberate boost use must make a podium finish achievable")
		failures += 1
	# Check sustained traffic behavior beyond a single three-lap race.
	race.restart()
	race.state = "racing"
	race.speed = 68
	var overlap_pairs := 0
	for frame in range(18000):
		race.distance += race.speed / 60
		race.brain.tick(race, 1.0 / 60)
		for i in range(7):
			for j in range(i + 1, 7):
				var a: Dictionary = race.rivals[i]
				var b: Dictionary = race.rivals[j]
				var gap := absf(wrapf(a.distance - b.distance, -race.track.length / 2, race.track.length / 2))
				if gap < 4.1 and absf(a.lane - b.lane) < 1.9:
					overlap_pairs += 1
	report.traffic_soak = {"seconds": 300, "cpu_overlap_pair_frames": overlap_pairs}
	if overlap_pairs > 0:
		push_error("CPU traffic must avoid driving through other CPU cars")
		failures += 1
	report.failures = failures
	print(JSON.stringify(report))
	var output := FileAccess.open("res://docs/balance-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
