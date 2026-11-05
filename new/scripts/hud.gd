extends Control

const DESIGN := Vector2(1280, 720)
const INK := Color("11121bc9")
const CYAN := Color("19dcff")
const BLUE := Color("087aff")
const WHITE := Color("f6f7fa")
const GOLD := Color("ffd52c")
const FONT = preload("res://assets/fonts/LiberationSans-BoldItalic.ttf")
const DRIVER_NAMES := ["RAY", "KAI", "EMMA", "LEO", "ACE", "MIA", "NOAH"]
const START_BUTTON := Rect2(466, 454, 348, 58)
var race: Node3D
var fingers: Dictionary = {}
var font: Font = FONT
var bottle_texture: Texture2D
var drift_texture: Texture2D
var coin_texture: Texture2D
var coin_balance := 0
var drift_combo := 0.0
var drift_fade := 0.0
var last_score := 0.0
var was_drifting := false
# The lap/time panel doubles as the touch pause control.
var buttons := {
	"left": Rect2(27, 562, 108, 108),
	"right": Rect2(159, 562, 108, 108),
	"drift": Rect2(937, 452, 98, 98),
	"boost": Rect2(909, 564, 106, 106),
	"pause": Rect2(894, 12, 376, 50),
}

func _ready() -> void:
	bottle_texture = load_icon("res://assets/ui/nitro-bottle.png")
	drift_texture = load_icon("res://assets/ui/drift-car.png")
	coin_texture = load_icon("res://assets/ui/coin.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var source: Texture2D = load(path)
	var texture := AtlasTexture.new()
	texture.atlas = source
	# Ignore almost invisible glow/noise when fitting generated art into a small HUD target.
	var image := source.get_image()
	var first := Vector2i(image.get_width(), image.get_height())
	var last := Vector2i.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	texture.region = Rect2i(first, last - first + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return texture

func draw_icon(texture: Texture2D, center: Vector2, bounds: Vector2) -> bool:
	if texture == null:
		return false
	var size_px := texture.get_size()
	size_px *= minf(bounds.x / size_px.x, bounds.y / size_px.y)
	draw_texture_rect(texture, Rect2(center - size_px / 2, size_px), false)
	return true

func ui_scale() -> float:
	var viewport := get_viewport_rect().size
	return minf(viewport.x / DESIGN.x, viewport.y / DESIGN.y)

func ui_offset() -> Vector2:
	return (get_viewport_rect().size - DESIGN * ui_scale()) / 2.0

func to_design(pos: Vector2) -> Vector2:
	return (pos - ui_offset()) / ui_scale()

func hit_button(action: String, pos: Vector2) -> bool:
	if not buttons.has(action):
		return false
	var rect: Rect2 = buttons[action]
	if action == "pause":
		return rect.has_point(pos)
	return pos.distance_to(rect.get_center()) <= rect.size.x / 2.0

func handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = event.index if event is InputEventScreenTouch else -1
	if not event.pressed:
		fingers.erase(index)
		return
	var p := to_design(event.position)
	if race.state in ["ready", "finished"]:
		if START_BUTTON.has_point(p):
			fingers.clear()
			race.restart()
	elif race.state == "paused":
		if START_BUTTON.has_point(p) or hit_button("pause", p):
			fingers.clear()
			race.state = "racing"
	elif hit_button("pause", p) and race.state == "racing":
		fingers.clear()
		race.state = "paused"
	else:
		move_pointer(index, event.position)

func move_pointer(index: int, pos: Vector2) -> void:
	fingers[index] = to_design(pos)

func held(action: String) -> bool:
	for pos in fingers.values():
		if hit_button(action, pos):
			return true
	return false

func touch_axis() -> float:
	return float(held("right")) - float(held("left"))

func _process(delta: float) -> void:
	if race == null:
		return
	if race.state in ["ready", "countdown"] or race.score < last_score:
		drift_combo = 0
		drift_fade = 0
		was_drifting = false
	if race.state == "racing":
		if race.drifting:
			if not was_drifting:
				drift_combo = 0
			drift_combo += maxf(0, race.score - last_score)
			drift_fade = 1.5
		else:
			drift_fade = maxf(0, drift_fade - delta)
		was_drifting = race.drifting
	last_score = race.score
	queue_redraw()

func text_at(pos: Vector2, value: String, size_px: int, color: Color = WHITE, shadow: bool = true) -> void:
	if shadow:
		draw_string(font, pos + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, color.a * 0.5))
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(pos: Vector2, value: String, size_px: int, color: Color = WHITE) -> void:
	text_at(pos - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2, 0), value, size_px, color)

func slant(rect: Rect2, color: Color = INK, cut: float = 16, fade: bool = false) -> PackedVector2Array:
	var p := PackedVector2Array([rect.position + Vector2(cut, 0), rect.position + Vector2(rect.size.x, 0), rect.end - Vector2(cut, 0), rect.position + Vector2(0, rect.size.y)])
	var end_color := Color(color, 0) if fade else color
	draw_polygon(p, PackedColorArray([color, end_color, end_color, color]))
	return p

func glow_line(points: PackedVector2Array, color: Color = CYAN, width: float = 2) -> void:
	for extra in [12, 6, 2]:
		draw_polyline(points, Color(color, color.a * 0.08), width + extra, true)
	draw_polyline(points, color, width, true)

func arc_points(center: Vector2, radius: float, start: float, end: float, steps: int = 80) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / steps)) * radius)
	return points

func time_label(seconds: float) -> String:
	return "%02d:%06.3f" % [int(seconds) / 60, fmod(seconds, 60)]

func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"name": "You", "distance": race.distance, "player": true, "car": race.player}]
	for i in range(race.rivals.size()):
		var rival: Dictionary = race.rivals[i]
		rows.append({"name": DRIVER_NAMES[i], "distance": rival.distance, "player": false, "car": rival.car})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance > b.distance)
	return rows

func _draw() -> void:
	if race == null:
		return
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	var rows := standings()
	draw_world_ranks(rows)
	draw_position(rows)
	draw_lap_time()
	draw_minimap()
	draw_drift_score()
	draw_controls()
	draw_speedometer()
	draw_nitro()
	draw_menu()

func draw_position(rows: Array[Dictionary]) -> void:
	slant(Rect2(8, 14, 219, 65), Color("171820df"), 19)
	slant(Rect2(20, 18, 80, 29), Color("0b0d13bd"), 8)
	text_at(Vector2(32, 40), "POS", 27)
	text_at(Vector2(103, 70), str(race.rank_position()), 76, GOLD)
	text_at(Vector2(153, 67), "/8", 42)
	var visible_rows: Array[int] = [0, 1, 2, 3]
	if race.rank_position() > 4:
		visible_rows[3] = race.rank_position() - 1
	for i in range(4):
		var rank: int = visible_rows[i]
		var row: Dictionary = rows[rank]
		var y := 94.0 + i * 30
		if row.player:
			var p := slant(Rect2(10, y, 210, 29), Color("0089dfc9"), 8, true)
			glow_line(PackedVector2Array([p[1], p[0], p[3], p[2]]), CYAN, 1.5)
		else:
			slant(Rect2(10, y, 209, 27), Color("11131cc4"), 8, true)
		text_at(Vector2(26, y + 23), str(rank + 1), 23)
		if row.player:
			draw_colored_polygon(PackedVector2Array([Vector2(58, y + 8), Vector2(65, y + 14), Vector2(57, y + 21)]), CYAN)
		text_at(Vector2(72, y + 22), row.name, 21)
	slant(Rect2(10, 234, 198, 39), Color("111723a6"), 8, true)
	draw_coin(Vector2(37, 253))
	text_at(Vector2(67, 264), comma_number(coin_balance), 29)

func comma_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result

func draw_coin(center: Vector2) -> void:
	if draw_icon(coin_texture, center, Vector2(38, 38)):
		return
	draw_circle(center + Vector2(1, 2), 18, Color("4c310b99"))
	draw_circle(center, 17, Color("e8a421"))
	draw_circle(center - Vector2(1, 1), 14, Color("ffdb51"))
	draw_arc(center, 13, 0, TAU, 40, Color("ad751a"), 1, true)
	var star := PackedVector2Array()
	for i in range(10):
		star.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * (11.0 if i % 2 == 0 else 5.0))
	draw_colored_polygon(star, Color("fff49e"))
	draw_polyline(star + PackedVector2Array([star[0]]), Color("d19622"), 1, true)

func draw_lap_time() -> void:
	slant(Rect2(894, 15, 378, 45), Color("15151cdb"), 15)
	text_at(Vector2(916, 46), "LAP", 25)
	text_at(Vector2(973, 52), str(mini(3, int(race.distance / race.track.length) + 1)), 47, GOLD)
	text_at(Vector2(1011, 46), "/3", 25)
	draw_line(Vector2(1063, 20), Vector2(1054, 56), Color("e4e5e8b3"), 1.3, true)
	var c := Vector2(1098, 37)
	draw_arc(c, 11, 0, TAU, 36, WHITE, 2.4, true)
	draw_line(c, c + Vector2(3, -7), WHITE, 2, true)
	draw_line(c + Vector2(-4, -15), c + Vector2(4, -15), WHITE, 2.8, true)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -11), WHITE, 2, true)
	draw_line(c + Vector2(8, -10), c + Vector2(11, -13), WHITE, 2, true)
	text_at(Vector2(1122, 46), time_label(race.elapsed), 29)

func map_point(d: float) -> Vector2:
	var p: Vector3 = race.track.point(d)
	return Vector2(1176, 132) + Vector2(p.x * 0.17 + p.z * 0.185, p.x * 0.1 - p.z * 0.142)

func draw_minimap() -> void:
	var points := PackedVector2Array()
	for i in range(129):
		points.append(map_point(race.track.length * i / 128.0))
	draw_polyline(points, Color("10121b8c"), 12, true)
	draw_polyline(points, Color("eeeeefd9"), 6, true)
	for i in range(race.rivals.size()):
		var p := map_point(float(race.rivals[i].distance))
		draw_circle(p, 7, Color("14141b"))
		draw_circle(p, 5, Color("ec3c55") if i == 0 else WHITE)
	var player_pos := map_point(race.distance)
	var heading := (map_point(race.distance + 5) - player_pos).angle()
	var arrow := PackedVector2Array()
	for p in [Vector2(13, 0), Vector2(-9, -8), Vector2(-5, 0), Vector2(-9, 8)]:
		arrow.append(player_pos + p.rotated(heading))
	draw_colored_polygon(arrow, GOLD)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color("473900"), 1.5, true)
	var finish := map_point(0) - Vector2(0, 15)
	draw_line(finish + Vector2(-8, 0), finish + Vector2(-8, 23), WHITE, 2, true)
	draw_rect(Rect2(finish - Vector2(8, 0), Vector2(24, 16)), Color("1c1d22"))
	for y in range(2):
		for x in range(4):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(finish + Vector2(-8 + x * 6, y * 8), Vector2(6, 8)), WHITE)

func draw_drift_score() -> void:
	if drift_fade <= 0:
		return
	var alpha := minf(1, drift_fade * 2)
	slant(Rect2(1124, 263, 170, 70), Color(0.07, 0.07, 0.12, alpha * 0.4), 13, true)
	text_at(Vector2(1165, 289), "DRIFT", 27, Color(WHITE, alpha))
	text_at(Vector2(1143, 319), "+%d pts" % int(drift_combo), 30, Color(GOLD, alpha))
	glow_line(PackedVector2Array([Vector2(1138, 333), Vector2(1279, 323)]), Color(CYAN, alpha), 2)

func round_button(action: String, neon: bool = false) -> void:
	var rect: Rect2 = buttons[action]
	var c := rect.get_center()
	var radius := rect.size.x / 2
	var active := held(action)
	draw_circle(c, radius, Color("12617b99") if active else Color("20232f48"))
	if neon:
		glow_line(arc_points(c, radius - 2, 0, TAU), Color(CYAN, 1.0 if active else 0.85), 2.4)
		draw_arc(c, radius - 7, PI * 1.15, PI * 1.85, 28, Color("ffffff88"), 1, true)
	else:
		draw_arc(c, radius - 1, 0, TAU, 80, Color("ffffffb8"), 2, true)

func draw_controls() -> void:
	for action in ["left", "right"]:
		round_button(action)
		var c: Vector2 = buttons[action].get_center()
		var sign_x := -1.0 if action == "left" else 1.0
		var chevron := PackedVector2Array()
		for p in [Vector2(-13, -27), Vector2(5, -27), Vector2(32, 0), Vector2(5, 27), Vector2(-13, 27), Vector2(13, 0)]:
			chevron.append(c + Vector2((p.x - 8) * sign_x, p.y))
		draw_colored_polygon(chevron, Color("ffffffe0"))
	round_button("drift")
	var c: Vector2 = buttons.drift.get_center()
	car_icon(c + Vector2(0, -12))
	centered(c + Vector2(0, 35), "DRIFT", 20)
	round_button("boost", true)
	c = buttons.boost.get_center()
	bottle(c + Vector2(0, -9), 0.75)
	centered(c + Vector2(0, 36), "BOOST", 20)

func car_icon(center: Vector2) -> void:
	if draw_icon(drift_texture, center + Vector2(0, 5), Vector2(51, 51)):
		return
	var silhouette := PackedVector2Array([Vector2(-17, 12), Vector2(-17, -3), Vector2(-12, -13), Vector2(12, -13), Vector2(17, -3), Vector2(17, 12), Vector2(11, 12), Vector2(11, 7), Vector2(-11, 7), Vector2(-11, 12)])
	var points := PackedVector2Array()
	for p in silhouette:
		points.append(center + p.rotated(0.22))
	draw_colored_polygon(points, WHITE)
	var windscreen := PackedVector2Array()
	for p in [Vector2(-9, -9), Vector2(9, -9), Vector2(12, -2), Vector2(-12, -2)]:
		windscreen.append(center + p.rotated(0.22))
	draw_colored_polygon(windscreen, Color("30333b"))
	for side in [-1, 1]:
		var trail := PackedVector2Array()
		for i in range(12):
			trail.append(center + Vector2(side * 9 + sin(i * 0.6) * 4 - i * 0.55, 13 + i * 1.5))
		draw_polyline(trail, WHITE, 3.2, true)

func bottle(center: Vector2, scale_factor: float = 1) -> void:
	if draw_icon(bottle_texture, center, Vector2(64, 80) * scale_factor):
		return
	var shape := [Vector2(-12, 22), Vector2(12, 22), Vector2(14, 17), Vector2(14, -14), Vector2(6, -21), Vector2(6, -28), Vector2(-6, -28), Vector2(-6, -21), Vector2(-14, -14), Vector2(-14, 17)]
	var points := PackedVector2Array()
	for p in shape:
		points.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(points, Color("0aabeb"))
	glow_line(points + PackedVector2Array([points[0]]), CYAN, 2)
	var bolt := PackedVector2Array()
	for p in [Vector2(2, -14), Vector2(-9, 3), Vector2(-1, 3), Vector2(-4, 16), Vector2(10, -4), Vector2(2, -4)]:
		bolt.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(bolt, WHITE)
	var cap := PackedVector2Array()
	for p in [Vector2(-8, -32), Vector2(8, -32), Vector2(8, -27), Vector2(-8, -27)]:
		cap.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(cap, WHITE)

func draw_speedometer() -> void:
	var c := Vector2(1150, 628)
	var radius := 124.0
	var start := PI * 0.94
	var end := TAU + 0.12
	# An open dial, tucked into the bottom-right corner as in the reference.
	draw_circle(c, radius - 5, Color("11121b55"))
	var arc := arc_points(c, radius, start, end)
	glow_line(arc, BLUE, 5)
	glow_line(arc_points(c, radius - 4, start, lerpf(start, end, 0.72)), Color("47dbff"), 3)
	glow_line(arc_points(c, radius, lerpf(start, end, 0.73), end), Color("ef3658"), 4)
	for i in range(36):
		var a := lerpf(start, end, i / 35.0)
		var major := i % 5 == 0
		var color := Color("f23c58") if i > 26 else Color("e3f4ff")
		draw_line(c + Vector2.from_angle(a) * (radius - 4), c + Vector2.from_angle(a) * (radius - (16 if major else 10)), color, 3 if major else 1.5, true)
	for i in range(8):
		var a := lerpf(start, end, i / 7.0)
		centered(c + Vector2.from_angle(a) * (radius - 30) + Vector2(0, 6), str(i), 19)
	var speed_kmh := int(race.speed * 3.6)
	centered(c + Vector2(-2, 2), str(speed_kmh), 66)
	centered(c + Vector2(1, 27), "km/h", 21)
	var gear := "N" if speed_kmh < 1 else str(clampi(ceili(race.speed / 13.0), 1, 6))
	var g := slant(Rect2(1200, 628, 51, 43), Color("15151b60"), 8)
	draw_polyline(g + PackedVector2Array([g[0]]), Color("ffffffe0"), 2, true)
	centered(Vector2(1224, 663), gear, 39)

func draw_nitro() -> void:
	bottle(Vector2(405, 660), 0.88)
	text_at(Vector2(443, 656), "NITRO", 28)
	var outline := PackedVector2Array([Vector2(442, 661), Vector2(847, 661), Vector2(835, 690), Vector2(431, 690), Vector2(442, 661)])
	draw_colored_polygon(outline.slice(0, 4), Color("101420b3"))
	draw_polyline(outline, Color("9ba6b8a6"), 3, true)
	glow_line(outline, Color("239efc66"), 1)
	var charge := clampf(race.nitro / 100.0, 0, 1)
	for i in range(9):
		var cell_fill := clampf(charge * 9 - i, 0, 1)
		if cell_fill <= 0:
			break
		var x := 444.0 + i * 43
		var width := 41.0 * cell_fill
		var points := PackedVector2Array([Vector2(x, 666), Vector2(x + width, 666), Vector2(x + width - 6, 684), Vector2(x - 6, 684)])
		draw_polygon(points, PackedColorArray([Color("b3ffff"), Color("6cffff"), Color("00b7ed"), Color("00c7ff")]))
		glow_line(PackedVector2Array([points[3], points[2]]), Color("16d9ffbb"), 1.5)

func draw_world_ranks(rows: Array[Dictionary]) -> void:
	if race.state != "racing":
		return
	var count := 0
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var gap := fposmod(float(row.distance) - race.distance, race.track.length)
		if row.player or gap > 100:
			continue
		var pos: Vector3 = row.car.position + Vector3.UP * 2.4
		if race.camera.is_position_behind(pos):
			continue
		var p := to_design(race.camera.unproject_position(pos))
		if p.x < 270 or p.x > 1080 or p.y < 100 or p.y > 500:
			continue
		slant(Rect2(p - Vector2(28, 21), Vector2(58, 26)), Color("16151dc4"), 6)
		var suffix := "st" if i == 0 else ("nd" if i == 1 else ("rd" if i == 2 else "th"))
		centered(p, str(i + 1) + suffix, 23)
		count += 1
		if count == 2:
			break

func draw_menu() -> void:
	if race.state == "countdown":
		slant(Rect2(568, 248, 144, 136), Color("11121bba"), 24)
		centered(Vector2(640, 353), str(maxi(1, ceili(race.countdown))), 100, GOLD)
	elif race.state in ["ready", "paused", "finished"]:
		draw_rect(Rect2(-ui_offset() / ui_scale(), get_viewport_rect().size / ui_scale()), Color("060b168f"))
		slant(Rect2(360, 183, 560, 358), Color("10121bec"), 30)
		glow_line(PackedVector2Array([Vector2(390, 183), Vector2(920, 183)]), CYAN, 2)
		text_at(Vector2(424, 230), "INITIAL SJ / ALPINE CIRCUIT", 19, CYAN)
		var title := "ALPINE RUSH" if race.state == "ready" else ("RACE PAUSED" if race.state == "paused" else "FINISH / P%d" % race.rank_position())
		text_at(Vector2(424, 289), title, 46)
		var detail := "8 DRIVERS. 3 LAPS. ONE WINNER."
		if race.state == "paused":
			detail = "P / ESC TO RESUME. R TO RESTART."
		elif race.state == "finished":
			detail = "TIME %s / DRIFT %d" % [time_label(race.elapsed), int(race.score)]
		text_at(Vector2(424, 337), detail, 20)
		text_at(Vector2(424, 374), "A / D STEER   SPACE DRIFT   SHIFT BOOST", 17, Color("adb6c5"))
		text_at(Vector2(424, 411), "BEST " + (time_label(race.best_time) if race.best_time > 0 else "--:--.---"), 20, GOLD)
		slant(START_BUTTON, CYAN, 13)
		var cta := "RESUME" if race.state == "paused" else ("RACE AGAIN / ENTER" if race.state == "finished" else "START RACE / ENTER")
		centered(Vector2(640, 491), cta, 25, Color("0a1b2b"))
