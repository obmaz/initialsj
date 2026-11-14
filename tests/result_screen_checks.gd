extends RefCounted
# The result popup shows this run against the best time instead of the settings buttons.
var failures := 0
var hud: Control


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	hud = r.hud
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
	# 결과에는 설정 버튼이 없고, 정지 팝업은 공용 설정을 연다.
	var sound: bool = r.sound_enabled
	r.state = "paused"
	r.hud.rev3.sync()
	r.hud.handle_pointer(_tap(r.hud.rev3.rect("settings").get_center()))
	check(r.state == "settings", "정지 팝업의 설정은 공용 설정을 연다")
	r.hud.rev3.sync()
	r.hud.handle_pointer(_tap(r.hud.rev3.rect("sound_toggle").get_center()))
	check(r.sound_enabled != sound, "공용 설정에서 효과음 스위치를 변경한다")
	# The FPS counter is an opt-in setting with its own row.
	check(not r.show_fps, "The FPS counter must be off by default")
	r.state = "settings"
	r.hud.handle_pointer(_tap(r.hud.SETTINGS_FPS.get_center()))
	check(r.show_fps, "The SHOW FPS row must switch the counter on")
	r.controls.settings_activate(4)
	check(not r.show_fps, "음악 항목 추가 후에도 패드의 FPS 항목이 실제 카운터를 전환한다")
	for mode in ["tour", "track"]:
		r.choose_mode(mode, 2)
		var original_size := tree.root.size
		for viewport in [Vector2i(960, 720), Vector2i(1440, 720)]:
			tree.root.size = viewport
			await tree.process_frame
			for variant in ["finished", "failed", "new_record"]:
				r.state = "failed" if variant == "failed" else "finished"
				r.new_record = variant == "new_record"
				r.hud.rev3.sync()
				for id in ["retry", "continue"]:
					var content: Dictionary = r.hud.rev3.button_content(id, id + "_icon", 90 if id == "retry" else 28)
					var bounds: Rect2 = r.hud.rev3.rect(id)
					check(not content.icon.intersects(content.label), "모든 결과 상태에서 아이콘과 글자 영역이 겹치지 않는다")
					check(
						bounds.encloses(content.icon) and bounds.encloses(content.label),
						"결과 버튼의 그림·문구는 4:3~2:1 안전 영역 안에 남는다"
					)
			r.new_record = false
		tree.root.size = original_size
		var destination := "courses" if mode == "track" else "menu"
		check(r.result_button_label() == ("SELECT TRACK" if mode == "track" else "SELECT MODE"), "결과 버튼 문구와 목적지가 일치한다")
		for result in ["finished", "failed"]:
			for control in ["touch", "enter", "escape", "pad_a", "pad_b", "back"]:
				r.state = result
				r.result_age = 2
				match control:
					"touch":
						r.hud.handle_pointer(_tap(r.hud.result_continue_rect().get_center()))
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
	event.position = design_point * hud.ui_scale() + hud.ui_offset()
	return event
