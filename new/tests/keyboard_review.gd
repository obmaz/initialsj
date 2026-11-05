extends SceneTree
# Exercise actual keyboard input through the scene, including a clean drift release.
var held := {}
func _initialize():
	call_deferred("run")
func key(code: Key, down: bool):
	if held.get(code, false) == down:
		return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run():
	if DisplayServer.get_name() == "headless":
		push_error("Keyboard visual review requires a graphical display")
		quit(2)
		return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.save_records = false
	race.sound_enabled = false
	await process_frame
	key(KEY_ENTER, true)
	await process_frame
	key(KEY_ENTER, false)
	var saw_drift := false
	var saw_boost := false
	var saw_turbo := false
	var captured := false
	for frame in range(1200):
		await physics_frame
		var t: float = race.elapsed
		var drifting := t > 4.5 and t < 5.3
		var target := -3.2 if t < 1.5 or t >= 5.3 else 3.2
		key(KEY_A, drifting or (not drifting and race.lane > target + 0.25))
		key(KEY_D, not drifting and race.lane < target - 0.25)
		key(KEY_SPACE, drifting)
		key(KEY_SHIFT, t > 3 and t < 4.2)
		saw_drift = saw_drift or race.drifting
		saw_boost = saw_boost or race.boosting
		saw_turbo = saw_turbo or race.mini_turbo > 0
		if t > 5.1 and not captured:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/feel-keyboard-corner.png")
			captured = true
		if t > 8:
			break
	for code in held.keys():
		key(code, false)
	var report := {"drift_input":saw_drift,"boost_input":saw_boost,"mini_turbo":saw_turbo,"score":snappedf(race.score, 0.01),"lane":snappedf(race.lane, 0.01),"elapsed":snappedf(race.elapsed, 0.01)}
	print(JSON.stringify(report))
	var output := FileAccess.open("res://docs/keyboard-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	race.queue_free()
	await process_frame
	await process_frame
	quit(0 if saw_drift and saw_boost and saw_turbo else 1)
