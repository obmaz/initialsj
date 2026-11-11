extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	# 실제 차체의 높이별 충돌은 world_car_checks 및 tour_world_checks에서 검증한다.
	var budget = race.render_budget
	race.state = "racing"
	race.elapsed = 10
	budget.set_mode(0, race)
	budget.level = 0
	for frame in range(31):
		budget.last_tick = Time.get_ticks_usec() - 33334
		budget.tick(race)
	race.pause_tour()
	budget.tick(race)
	check(budget.slow_windows == 0, "Pausing must break a sequence of slow quality windows")
	race.state = "racing"
	for frame in range(31):
		budget.last_tick = Time.get_ticks_usec() - 33334
		budget.tick(race)
	check(budget.level == 0, "A fresh single slow window after pause must not degrade quality")
	budget.set_mode(0, race)
	budget.level = 0
	for frame in range(2):
		budget.last_tick = Time.get_ticks_usec() - 1000000
		budget.tick(race)
	check(budget.level == 1, "Repeated one-second foreground frames must trigger automatic quality reduction")
	check(
		race.hud.hit_button("pause", race.hud.PAUSE_BUTTON.position + Vector2(-5, 30)),
		"The pause icon needs a phone-sized padded touch target"
	)
	FileAccess.open(Report.path("driving-state-metrics.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{
					"assertions": assertions,
					"failures": failures,
					"checks":
					[
						"CPU airborne landing versus grounded puddle crossing",
						"incline world-height clearance in helper and actual collision step",
						"pause breaks slow quality windows",
						"foreground one-second frames lower AUTO quality",
						"expanded mobile pause touch target"
					]
				},
				"\t"
			)
			+ "\n"
		)
	)
	race.queue_free()
	await tree.process_frame
	print(
		"Driving state / incline / CPU landing / quality / pause: ", "PASS" if failures == 0 else "FAIL (%d)" % failures
	)
	return failures
