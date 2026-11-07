extends RefCounted
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "racing"
	race.elapsed = 10
	var budget = race.render_budget
	budget.set_mode(0,race)
	budget.level = 0
	for frame in range(65):
		budget.last_tick = Time.get_ticks_usec()-33334
		budget.tick(race)
	check(budget.level == 1,"Sustained 30 FPS must lower automatic quality after two windows")
	for frame in range(65):
		budget.last_tick = Time.get_ticks_usec()-33334
		budget.tick(race)
	check(budget.level == 2,"Automatic quality must reach the fast setting if poor pacing continues")
	check(race.sun_light.directional_shadow_max_distance == 75,"Fast quality must shorten the expensive shadow range")
	budget.set_mode(1,race)
	for frame in range(65):
		budget.last_tick = Time.get_ticks_usec()-33334
		budget.tick(race)
	check(budget.level == 0,"Manual high quality must honor the player's choice")
	budget.set_mode(0,race)
	race.state = "paused"
	budget.last_tick = Time.get_ticks_usec()-2000000
	budget.tick(race)
	check(budget.frames == 0 and budget.seconds == 0,"Pauses and background stalls must not degrade automatic quality")
	race.lite_graphics = true
	budget.set_mode(0,race)
	check(budget.level == 2,"Low-memory consoles must start on the lightest rendering level")
	race.queue_free()
	await tree.process_frame
	print("Adaptive render quality / manual override / paused timing: ","PASS" if failures == 0 else "FAIL")
	return failures
