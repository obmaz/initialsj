extends RefCounted
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const SIDE := [Rect2(350, 148, 280, 80), Rect2(650, 148, 280, 80)]
const SIZE := [Rect2(350, 276, 180, 80), Rect2(550, 276, 180, 80), Rect2(750, 276, 180, 80)]
const RESET := Rect2(350, 558, 280, 80)
const DONE := Rect2(650, 558, 280, 80)


static func draw(hud: Control) -> void:
	hud.menu_text.begin()
	hud.draw_rect(Rect2(0, 0, 1280, 720), Color("081220"))
	hud.modal_begin()
	MenuTheme.label(hud, Rect2(350, 38, 580, 64), "CONTROLS", 36, Color.WHITE)
	MenuTheme.label(hud, Rect2(350, 108, 580, 36), "STEERING SIDE", 23, Color("8caec0"))
	for i in range(2):
		choice(hud, SIDE[i], "LEFT" if i == 0 else "RIGHT", hud.race.touch_layout.mirrored == (i == 1))
	MenuTheme.label(hud, Rect2(350, 236, 580, 36), "BUTTON SIZE", 23, Color("8caec0"))
	for i in range(3):
		choice(hud, SIZE[i], ["SMALL", "MEDIUM", "LARGE"][i], hud.race.touch_layout.size_index == i)
	hud.configure_pedals()
	for action in hud.buttons:
		if action == "pause" or (action == "gas" and hud.race.auto_accelerate):
			continue
		if action == "cell" and hud.race.vehicle.mode != "hybrid":
			continue
		var rect: Rect2 = hud.buttons[action]
		var centre := Vector2(350, 390) + (rect.get_center() - Vector2(0, 410)) * .45
		hud.draw_circle(centre, rect.size.x * .225, Color("153648"))
		hud.draw_arc(centre, rect.size.x * .225, 0, TAU, 24, Color("00e5ff"), 1.5, true)
		MenuTheme.label(
			hud, Rect2(centre - Vector2(30, 12), Vector2(60, 24)), action.to_upper(), 12, Color.WHITE, true, 8
		)
	var rest: Vector2 = hud.HudLayout.steering_rest(hud.race.touch_layout.mirrored)
	var stick: Vector2 = Vector2(350, 390) + (rest - Vector2(0, 410)) * .45
	hud.draw_circle(stick, 32, Color("153648"))
	hud.draw_arc(stick, 32, 0, TAU, 32, Color("00e5ff"), 1.5, true)
	hud.draw_circle(stick, 11, Color("adc1ce"))
	choice(hud, RESET, "RESET", false)
	choice(hud, DONE, "DONE", true)
	if hud.pad_on():
		var targets: Array[Rect2] = [SIDE[0].merge(SIDE[1]), SIZE[0].merge(SIZE[2]), RESET, DONE]
		hud.draw_rect(targets[clampi(hud.race.settings_focus, 0, 3)].grow(3), Color("00e5ff"), false, 2)
	hud.modal_end()


static func choice(hud: Control, rect: Rect2, label: String, active: bool) -> void:
	hud.glass_box(rect, 12, Color("12374b") if active else Color("0d1d33"), Color("00e5ff"), 1.5)
	MenuTheme.label(hud, rect, label, 24, Color("00e5ff") if active else Color.WHITE, true, 14)


static func press(hud: Control, at: Vector2) -> void:
	for i in range(2):
		if SIDE[i].has_point(at):
			hud.race.touch_layout.mirrored = i == 1
	for i in range(3):
		if SIZE[i].has_point(at):
			hud.race.touch_layout.size_index = i
	if RESET.has_point(at):
		hud.race.touch_layout.reset()
	if DONE.has_point(at):
		hud.race.close_settings()
	hud.clear_driving_input()
	hud.race.save_preferences()
