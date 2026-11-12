extends RefCounted
# The result popup shows this run against the best time instead of the settings buttons.
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	r.choose_mode("tour")
	await tree.physics_frame
	r.restart()
	r.state = "racing"
	r.best_time = 0
	r.elapsed = 100.0
	r.finish()
	check(r.new_record and r.best_time == 100.0 and r.previous_best == 0, "A first finish must be a new record")
	r.restart()
	r.state = "racing"
	r.elapsed = 120.0
	r.finish()
	check(
		not r.new_record and r.best_time == 100.0 and r.previous_best == 100.0,
		"A slower finish must keep the best and report no record"
	)
	r.restart()
	r.state = "racing"
	r.elapsed = 90.5
	r.finish()
	check(r.new_record and r.best_time == 90.5 and r.previous_best == 100.0, "A faster finish must beat the best")
	r.load_record()
	check(not r.new_record and r.previous_best == 0, "Reloading a record must clear the previous run's flags")
	# The settings buttons only work on the pause screen.
	var sound: bool = r.sound_enabled
	r.state = "finished"
	r.hud.handle_pointer(_tap(r.hud.SOUND_BUTTON.get_center()))
	check(r.sound_enabled == sound, "The result popup must not toggle sound")
	r.state = "paused"
	r.hud.handle_pointer(_tap(r.hud.SOUND_BUTTON.get_center()))
	check(r.sound_enabled != sound, "The pause screen must still toggle sound")
	# The FPS counter is an opt-in setting with its own row.
	check(not r.show_fps, "The FPS counter must be off by default")
	r.state = "settings"
	r.hud.handle_pointer(_tap(r.hud.SETTINGS_FPS.get_center()))
	check(r.show_fps, "The SHOW FPS row must switch the counter on")
	r.controls.settings_activate(3)
	check(not r.show_fps, "Pad row 3 must toggle the FPS counter")
	for mode in ["tour", "track"]:
		r.choose_mode(mode, 2)
		var destination := "courses" if mode == "track" else "menu"
		check(r.result_button_label() == ("SELECT TRACK" if mode == "track" else "SELECT MODE"), "결과 버튼 문구와 목적지가 일치한다")
		for result in ["finished", "failed"]:
			for control in ["touch", "enter", "escape", "pad_a", "pad_b", "back"]:
				r.state = result
				match control:
					"touch":
						r.hud.handle_pointer(_tap(r.hud.START_BUTTON.get_center()))
					"enter", "escape":
						var event := InputEventKey.new()
						event.pressed = true
						event.keycode = KEY_ENTER if control == "enter" else KEY_ESCAPE
						r.controls.handle(event)
					"pad_a", "pad_b":
						r.controls.pad_pressed(JOY_BUTTON_A if control == "pad_a" else JOY_BUTTON_B)
					"back":
						r.navigate_back()
				check(r.state == destination, "종료 후 입력 경로가 같은 선택 화면으로 연결된다: " + mode + "/" + result + "/" + control)
	r.queue_free()
	await tree.process_frame
	print("Result popup records / pad Back pause / options only when paused: ", "PASS" if failures == 0 else "FAIL")
	return failures


func _tap(design_point: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = design_point
	return event
