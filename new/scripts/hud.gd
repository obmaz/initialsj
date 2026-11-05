extends Control

const INK := Color("0b192ce8")
const CYAN := Color("42e2f4")
const WHITE := Color("edf5f6")
const GOLD := Color("ffce59")
var race: Node3D
var fingers: Dictionary = {}
var font: Font = ThemeDB.fallback_font
var buttons := {"left": Rect2(34, 599, 88, 88), "right": Rect2(136, 599, 88, 88), "brake": Rect2(248, 620, 85, 62), "drift": Rect2(1050, 536, 88, 88), "boost": Rect2(1152, 599, 94, 88), "pause": Rect2(606, 24, 60, 42)}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func to_design(pos: Vector2) -> Vector2:
	return pos * Vector2(1280, 720) / get_viewport_rect().size

func handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = event.index if event is InputEventScreenTouch else -1
	if event.pressed:
		var p := to_design(event.position)
		if race.state in ["ready", "finished"]:
			if Rect2(466, 454, 348, 58).has_point(p):
				race.restart()
		elif race.state == "paused":
			if Rect2(466, 454, 348, 58).has_point(p):
				race.state = "racing"
		elif buttons.pause.has_point(p) and race.state == "racing":
			race.state = "paused"
		else:
			move_pointer(index, event.position)
	else:
		fingers.erase(index)

func move_pointer(index: int, pos: Vector2) -> void:
	fingers[index] = to_design(pos)

func held(action: String) -> bool:
	for p in fingers.values():
		if buttons[action].has_point(p):
			return true
	return false

func touch_axis() -> float:
	return float(held("right")) - float(held("left"))

func text_at(pos: Vector2, value: String, size_px: int, color: Color = WHITE) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func panel(rect: Rect2, color: Color = INK) -> void:
	draw_style_box(style(color), rect)

func style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s

func time_label(seconds: float) -> String:
	return "%02d:%06.3f" % [int(seconds) / 60, fmod(seconds, 60)]

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, get_viewport_rect().size / Vector2(1280, 720))
	panel(Rect2(28, 24, 232, 98))
	draw_rect(Rect2(28, 24, 4, 98), CYAN)
	text_at(Vector2(48, 51), "POSITION", 13, CYAN)
	text_at(Vector2(48, 105), str(race.rank_position()).pad_zeros(2), 52, GOLD)
	text_at(Vector2(130, 99), "/ 08", 24)
	panel(Rect2(28, 134, 232, 103))
	text_at(Vector2(48, 160), "ALPINE CIRCUIT", 14, CYAN)
	text_at(Vector2(48, 190), "YOU  /  CRIMSON GT", 18)
	text_at(Vector2(48, 219), "DRIFT   %06d PTS" % int(race.score), 16, GOLD)
	panel(Rect2(844, 24, 408, 66))
	text_at(Vector2(863, 49), "LAP", 13, CYAN)
	text_at(Vector2(863, 77), "%d / 3" % mini(3, int(race.distance / race.track.length) + 1), 25, GOLD)
	draw_line(Vector2(965, 37), Vector2(965, 77), Color("466072"), 1)
	text_at(Vector2(987, 49), "RACE TIME", 13, CYAN)
	text_at(Vector2(987, 77), time_label(race.elapsed), 26)
	panel(buttons.pause)
	text_at(Vector2(626, 52), "II", 23)
	# Mini map uses the same sampled course as the simulation.
	panel(Rect2(1072, 105, 180, 178), Color("0b192cb0"))
	var map_points := PackedVector2Array()
	for i in range(101):
		map_points.append(map_point(race.track.length * i / 100.0))
	draw_polyline(map_points, Color("6f8c9b"), 6, true)
	for rival in race.rivals:
		draw_circle(map_point(float(rival.distance)), 3, WHITE)
	draw_circle(map_point(race.distance), 6, GOLD)
	text_at(Vector2(1091, 267), "N  /  LAKE ROUTE", 11, CYAN)
	# Speed dial and nitro reserve.
	var center := Vector2(1158, 484)
	draw_circle(center, 87, Color("0b192cc9"))
	draw_arc(center, 81, PI * 0.8, PI * 2.2, 60, Color("426071"), 5, true)
	draw_arc(center, 81, PI * 0.8, PI * (0.8 + 1.4 * clampf(race.speed / 77, 0, 1)), 60, CYAN, 5, true)
	text_at(center + Vector2(-55, 13), "%03d" % int(race.speed * 3.6), 51)
	text_at(center + Vector2(-26, 37), "KM / H", 13, CYAN)
	panel(Rect2(415, 631, 450, 57))
	text_at(Vector2(432, 651), "NITRO", 12, CYAN)
	text_at(Vector2(763, 651), "%03d %%" % int(race.nitro), 12)
	draw_rect(Rect2(433, 662, 414, 10), Color("29465c"))
	draw_rect(Rect2(433, 662, 414 * race.nitro / 100, 10), CYAN)
	text_at(Vector2(438, 711), "A / D  STEER     SPACE  DRIFT     SHIFT  NITRO     S  BRAKE", 12)
	for action in ["left", "right", "brake", "drift", "boost"]:
		var r: Rect2 = buttons[action]
		panel(r, Color("176276dc") if held(action) else Color("102438c9"))
		draw_rect(r.grow(-1), Color("4a7b8b"), false, 1)
		var label: String = {"left": "<", "right": ">", "brake": "BRAKE", "drift": "DRIFT", "boost": "BOOST"}[action]
		var size_px := 38 if action in ["left", "right"] else 16
		text_at(r.position + Vector2((r.size.x - font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x) / 2, r.size.y / 2 + 8), label, size_px, CYAN if action == "boost" else WHITE)
	if race.drifting and race.state == "racing":
		text_at(Vector2(543, 154), "DRIFT +%d" % int(race.score), 28, GOLD)
	if race.boosting and race.state == "racing":
		text_at(Vector2(556, 194), "NITRO ACTIVE", 19, CYAN)
	if race.state == "countdown":
		panel(Rect2(560, 254, 160, 128))
		text_at(Vector2(612, 348), str(maxi(1, ceili(race.countdown))), 80, GOLD)
	elif race.state in ["ready", "paused", "finished"]:
		draw_rect(Rect2(0, 0, 1280, 720), Color("0614269c"))
		panel(Rect2(380, 185, 520, 355), Color("0a1a2ef5"))
		draw_rect(Rect2(380, 185, 520, 4), CYAN)
		text_at(Vector2(424, 230), "INITIAL SJ   /   VOL. 01", 16, CYAN)
		var title := "ALPINE RUSH" if race.state == "ready" else ("RACE PAUSED" if race.state == "paused" else "FINISH  /  P%d" % race.rank_position())
		text_at(Vector2(424, 289), title, 42)
		var detail := "A mountain road. Eight drivers. Three laps."
		if race.state == "paused":
			detail = "P / ESC to resume. R to restart."
		elif race.state == "finished":
			detail = "TIME  %s     DRIFT  %d" % [time_label(race.elapsed), int(race.score)]
		text_at(Vector2(424, 331), detail, 18)
		text_at(Vector2(424, 367), "Auto acceleration / keyboard + touch controls", 16, Color("9bb5c9"))
		text_at(Vector2(424, 403), "BEST  " + (time_label(race.best_time) if race.best_time > 0 else "--:--.---"), 17, GOLD)
		panel(Rect2(466, 454, 348, 58), CYAN)
		var cta := "RESUME" if race.state == "paused" else ("RACE AGAIN  /  ENTER" if race.state == "finished" else "START RACE  /  ENTER")
		text_at(Vector2(501, 491), cta, 21, Color("0b2133"))

func map_point(d: float) -> Vector2:
	var p: Vector3 = race.track.point(d)
	return Vector2(1162, 183) + Vector2(p.x, p.z) * 0.19
