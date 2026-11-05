extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	race.state = "racing"
	check(race.rank_position() == 8, "Player must start behind the seven CPU opponents")
	for r in race.rivals:
		r.distance = race.track.length * 0.5
	var t100 := 0.0
	var t200 := 0.0
	for i in range(240):
		race.step(1.0 / 60, 0, false, false, false)
		if t100 == 0 and race.speed * 3.6 >= 100:
			t100 = race.elapsed
		if t200 == 0 and race.speed * 3.6 >= 200:
			t200 = race.elapsed
	var cruise: float = race.speed * 3.6
	check(t200 > 0 and t200 < 3.1, "Acceleration must reach 200 km/h within 3.1 seconds on clear road")
	for i in range(120):
		race.step(1.0 / 60, 0, false, true, false)
	var turbo: float = race.speed * 3.6
	check(turbo > 300 and turbo <= 317, "Nitro must produce a meaningful but bounded speed increase")
	race.lane = -3
	race.lane_velocity = 0
	for i in range(48):
		race.step(1.0 / 60, 0.35, true, false, false)
	race.step(1.0 / 60, 0, false, false, false)
	check(race.mini_turbo > 0, "Clean drift release must award a mini turbo")
	# A faster opponent must pass a deliberately slower car instead of sitting in its lane.
	race.restart()
	race.state = "racing"
	race.distance = 112
	race.lane = -3
	race.speed = 36
	for r in race.rivals:
		r.distance = race.track.length * 0.5
	var rival: Dictionary = race.rivals[0]
	rival.distance = 100.0
	rival.lane = -3.0
	rival.speed = 62.0
	var lateral := 0.0
	for i in range(240):
		race.distance += race.speed / 60
		race.brain.tick(race, 1.0 / 60)
		lateral = maxf(lateral, absf(float(rival.lane) + 3))
	check(rival.distance > race.distance and lateral > 1.9, "CPU must change lanes and pass a slower player")
	var passed_within_four_seconds: bool = rival.distance > race.distance
	var ai_boosted := false
	for i in range(7200):
		race.distance += 60.0 / 60
		race.brain.tick(race, 1.0 / 60)
		for r in race.rivals:
			check(is_finite(r.distance) and absf(r.lane) <= 6.3 and r.speed <= 88.01 and r.speed >= 0, "CPU must respect road and speed limits")
			ai_boosted = ai_boosted or r.boosting
	check(ai_boosted, "CPU must use its finite nitro reserve on open road")
	race.restart()
	race.state = "racing"
	for i in range(10800):
		var rate: float = wrapf(race.track.heading(race.distance + 16) - race.track.heading(race.distance), -PI, PI) / 16
		var correction: float = clampf(((-3.2 - race.lane) * 1.5 - rate * race.speed * race.speed * 0.04) / 7.6, -1, 1)
		race.step(1.0 / 60, correction, false, false, false)
		if race.state == "finished":
			break
	check(race.state == "finished", "A line-following driver must be able to complete the race")
	var full_rank: int = race.rank_position()
	var full_time: float = race.elapsed
	var report := {"zero_to_100_seconds": snappedf(t100, 0.001), "zero_to_200_seconds": snappedf(t200, 0.001), "cruise_kmh": snappedf(cruise, 0.1), "nitro_kmh": snappedf(turbo, 0.1), "cpu_passed_slow_car": passed_within_four_seconds, "cpu_lateral_movement_m": snappedf(lateral, 0.1), "cpu_simulated_seconds": 124, "line_following_no_boost_rank": full_rank, "line_following_race_seconds": snappedf(full_time, 0.01), "failures": failures}
	print(JSON.stringify(report))
	var output := FileAccess.open("res://docs/game-feel-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
