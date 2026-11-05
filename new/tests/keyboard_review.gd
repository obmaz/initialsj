extends SceneTree
# Drive with real input events; check gas, brake priority and brake-tap drifting.
var held := {}
func _initialize() -> void: call_deferred("run")
func key(code: Key, down: bool) -> void:
	if held.get(code,false) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Keyboard review requires a graphical display")
		quit(2)
		return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.save_records = false
	race.sound_enabled = false
	await process_frame
	key(KEY_ENTER,true)
	await process_frame
	key(KEY_ENTER,false)
	key(KEY_W,true)
	var saw_gas := false
	var saw_brake := false
	var saw_drift := false
	var captured := false
	var entry_speed := 0.0
	var braked_speed := 0.0
	for frame in range(1000):
		await physics_frame
		var t: float = race.elapsed
		key(KEY_S,t > 2.8 and t < 3.0)
		key(KEY_D,t > 2.8 and t < 3.6)
		saw_gas = saw_gas or (race.throttling and race.speed > 30)
		saw_brake = saw_brake or race.braking
		saw_drift = saw_drift or race.drifting
		if t > 2.7 and t < 2.8: entry_speed = race.speed
		if race.braking: braked_speed = race.speed
		if t > 3.4 and not captured:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/tour/keyboard-drift.png")
			captured = true
		if t > 5: break
	for code in held.keys(): key(code,false)
	var report := {"gas_input":saw_gas,"brake_input":saw_brake,"brake_reduced_speed":braked_speed < entry_speed,"brake_tap_drift":saw_drift,"elapsed":snappedf(race.elapsed,0.01)}
	print(JSON.stringify(report))
	var output := FileAccess.open("res://docs/keyboard-metrics.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	race.queue_free()
	await process_frame
	await process_frame
	quit(0 if saw_gas and saw_brake and saw_drift and braked_speed < entry_speed else 1)
