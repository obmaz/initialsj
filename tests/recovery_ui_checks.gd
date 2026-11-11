extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func touch(race: Node3D, index: int, pressed: bool, design: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = design * race.hud.ui_scale() + race.hud.ui_offset()
	race.hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	var original_size := tree.root.size
	for choice in [["tour", 0], ["track", 0], ["track", 1]]:
		race.choose_mode(choice[0], choice[1])
		race.state = "racing"
		race.recovery.available = true
		check(race.hud.recovery_visible(), "Every driving mode must expose recovery when it becomes available")
		for state in ["paused", "menu", "courses", "ready", "settings", "countdown", "finished", "failed"]:
			race.state = state
			check(not race.hud.recovery_visible(), "Recovery must not appear on " + state)
	race.choose_mode("tour")
	for viewport in [Vector2i(1280, 720), Vector2i(896, 414)]:
		tree.root.size = viewport
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		race.recovery.available = false
		check(not race.hud.recovery_visible(), "Ordinary driving must not show an unnecessary recovery control")
		touch(race, 1, true, race.hud.buttons.gas.get_center())
		touch(race, 2, true, race.hud.buttons.right.get_center())
		race.recovery.available = true
		var edge: Vector2 = race.hud.recovery_touch_rect().position + Vector2(4, 38)
		touch(race, 3, true, edge)
		check(
			not race.recovery_available, "A touch just outside the drawn recovery button must invoke real car recovery"
		)
		check(
			race.hud.held("gas") and race.hud.held("right"),
			"Car recovery must preserve other fingers holding gas and steering"
		)
		check(
			not race.hud.fingers.has(3) and race.hud.recovery_touches.has(3),
			"The recovery pointer must be captured rather than becoming a driving control"
		)
		race.hud.move_pointer(3, race.hud.buttons.gas.get_center() * race.hud.ui_scale() + race.hud.ui_offset())
		check(not race.hud.fingers.has(3), "Dragging a held recovery finger must not leak into the gas control")
		race.recovery.available = true
		touch(race, 3, true, edge)
		check(
			race.recovery_available, "A duplicate press for the same held finger must not invoke recovery a second time"
		)
		touch(race, 3, false, edge)
		check(not race.hud.recovery_touches.has(3), "Pointer release must release the recovery capture")
		touch(race, 3, true, edge)
		check(not race.recovery_available, "A fresh press after release must remain usable")
		touch(race, 3, false, edge)
		touch(race, 1, false, race.hud.buttons.gas.get_center())
		touch(race, 2, false, race.hud.buttons.right.get_center())
	var target: Rect2 = race.hud.recovery_touch_rect()
	for rect in [
		race.hud.pause_touch_rect(),
		race.hud.route_touch_rect(0),
		race.hud.route_touch_rect(1),
		Rect2(488, 246, 304, 48),
		Rect2(1087, 83, 185, 132)
	]:
		check(
			not target.intersects(rect),
			"Recovery must not overlap the route choices, pause target, boost badge or minimap"
		)
	for action in ["gas", "brake", "left", "right", "nitro", "drift"]:
		check(not target.intersects(race.hud.buttons[action]), "Recovery must stay separate from " + action)
	check(
		ceili(target.size.y * 414.0 / 720) >= 44,
		"The recovery touch target must be approximately 44 screen pixels on a landscape phone"
	)
	var setting_rects: Array[Rect2] = [
		race.hud.SETTINGS_SOUND,
		race.hud.SETTINGS_MOTION,
		race.hud.SETTINGS_GRAPHICS,
		race.hud.SETTINGS_FULLSCREEN,
		race.hud.SETTINGS_INSTALL,
		race.hud.SETTINGS_CLOSE
	]
	for i in range(setting_rects.size()):
		check(
			setting_rects[i].size.y * 414.0 / 720 >= 44,
			"Fullscreen and existing settings controls must retain large touch targets"
		)
		check(
			Rect2(300, 40, 680, 640).encloses(setting_rects[i]),
			"All settings controls must fit inside the enlarged panel"
		)
		for j in range(i):
			check(not setting_rects[i].intersects(setting_rects[j]), "Settings rows must not overlap")
	race.hud.recovery_touches[8] = true
	race.state = "paused"
	race.hud._process(0)
	check(
		race.hud.recovery_touches.is_empty(),
		"Pausing or leaving the race must clear obsolete recovery pointer captures"
	)
	tree.root.size = original_size
	race.queue_free()
	await tree.process_frame
	print(
		"Recovery actual touch / multitouch ownership / screen visibility / settings targets: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
