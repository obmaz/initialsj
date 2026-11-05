extends Control

const DESIGN := Vector2(1280, 720)
const INK := Color("11121bc9")
const CYAN := Color("19dcff")
const BLUE := Color("087aff")
const WHITE := Color("f6f7fa")
const GOLD := Color("ffda22")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
const CAPTION_FONT = preload("res://assets/fonts/LiberationSans-BoldItalic.ttf")
const POSITION_FONT = preload("res://assets/fonts/PositionNumeral.tres")
const NUMBER_FONT = preload("res://assets/fonts/Roboto-BlackItalic.ttf")
const DRIVER_NAMES := ["RAY", "KAI", "EMMA", "LEO", "ACE", "MIA", "NOAH"]
const START_BUTTON := Rect2(466, 454, 348, 58)
var race: Node3D
var fingers: Dictionary = {}
var font: Font = FONT
var bottle_texture: Texture2D
var drift_texture: Texture2D
var coin_texture: Texture2D
var dial_backdrop: GradientTexture2D
var minimap_route := Curve2D.new()
var minimap_points := PackedVector2Array()
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
	build_minimap()
	build_dial_backdrop()
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

func draw_icon(texture: Texture2D, center: Vector2, bounds: Vector2, rotation: float = 0) -> bool:
	if texture == null:
		return false
	var size_px := texture.get_size()
	size_px *= minf(bounds.x / size_px.x, bounds.y / size_px.y)
	if rotation != 0:
		draw_set_transform(ui_offset() + center * ui_scale(), rotation, Vector2.ONE * ui_scale())
		draw_texture_rect(texture, Rect2(-size_px / 2, size_px), false)
		draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	else:
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

func text_at(pos: Vector2, value: String, size_px: int, color: Color = WHITE, shadow: bool = true, face: Font = FONT) -> void:
	if shadow:
		draw_string_outline(face, pos + Vector2(0.5, 1.5), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 2, Color(0.02, 0.02, 0.04, color.a * 0.38))
	draw_string(face, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(pos: Vector2, value: String, size_px: int, color: Color = WHITE, face: Font = FONT) -> void:
	text_at(pos - Vector2(face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2, 0), value, size_px, color, true, face)

func slant(rect: Rect2, color: Color = INK, cut: float = 16, fade: bool = false) -> PackedVector2Array:
	var p := PackedVector2Array([rect.position + Vector2(cut, 0), rect.position + Vector2(rect.size.x, 0), rect.end - Vector2(cut, 0), rect.position + Vector2(0, rect.size.y)])
	if fade:
		# Hold the dark/blue colour under the lettering, then feather the trailing edge.
		var top := p[0].lerp(p[1], 0.52)
		var bottom := p[3].lerp(p[2], 0.52)
		draw_colored_polygon(PackedVector2Array([p[0], top, bottom, p[3]]), color)
		draw_polygon(PackedVector2Array([top, p[1], p[2], bottom]), PackedColorArray([color, Color(color, 0), Color(color, 0), color]))
	else:
		draw_colored_polygon(p, color)
	return p

func glow_line(points: PackedVector2Array, color: Color = CYAN, width: float = 2) -> void:
	for layer in [Vector2(18, 0.025), Vector2(11, 0.05), Vector2(5, 0.10), Vector2(2, 0.16)]:
		draw_polyline(points, Color(color, color.a * layer.y), width + layer.x, true)
	draw_polyline(points, color, width, true)

func rounded_polygon(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size()):
		var corner := points[i]
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		var enter := corner + (previous - corner).normalized() * radius
		var leave := corner + (next - corner).normalized() * radius
		for j in range(5):
			var t := j / 4.0
			result.append(enter.lerp(corner, t).lerp(corner.lerp(leave, t), t))
	return result

func build_dial_backdrop() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("101017a6"))
	gradient.set_color(1, Color("10101700"))
	gradient.add_point(0.65, Color("1010178c"))
	gradient.add_point(0.87, Color("10101744"))
	dial_backdrop = GradientTexture2D.new()
	dial_backdrop.width = 256
	dial_backdrop.height = 256
	dial_backdrop.gradient = gradient
	dial_backdrop.fill = GradientTexture2D.FILL_RADIAL
	dial_backdrop.fill_from = Vector2(0.5, 0.5)
	dial_backdrop.fill_to = Vector2(1, 0.5)

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
	draw_minimap(rows)
	draw_drift_score()
	draw_controls()
	draw_speedometer()
	draw_nitro()
	draw_menu()

func draw_position(rows: Array[Dictionary]) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(25, 14), Vector2(226, 14), Vector2(200, 78), Vector2(8, 78)]), Color("17171cdd"))
	slant(Rect2(23, 18, 72, 29), Color("090a10b3"), 7)
	text_at(Vector2(32, 40), "POS", 25)
	var ui_transform := Transform2D(Vector2(ui_scale(), 0), Vector2(0, ui_scale()), ui_offset())
	var numeral_transform := Transform2D(Vector2(1, 0), Vector2(-0.18, 1), Vector2(94, 70))
	draw_set_transform_matrix(ui_transform * numeral_transform)
	text_at(Vector2.ZERO, str(race.rank_position()), 72, GOLD, true, POSITION_FONT)
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	text_at(Vector2(151, 67), "/8", 40, WHITE, true, NUMBER_FONT)
	var visible_rows: Array[int] = [0, 1, 2, 3]
	if race.rank_position() > 4:
		visible_rows[3] = race.rank_position() - 1
	for i in range(4):
		var rank: int = visible_rows[i]
		var row: Dictionary = rows[rank]
		var y := 94.0 + i * 30
		if row.player:
			var p := slant(Rect2(10, y, 210, 29), Color("0062bce6"), 8, true)
			glow_line(PackedVector2Array([p[1], p[0], p[3], p[2]]), CYAN, 1.5)
		else:
			slant(Rect2(10, y, 209, 27), Color("11131cce"), 8, true)
		text_at(Vector2(26, y + 23), str(rank + 1), 23)
		if row.player:
			draw_colored_polygon(PackedVector2Array([Vector2(58, y + 8), Vector2(65, y + 14), Vector2(57, y + 21)]), CYAN)
		text_at(Vector2(72, y + 22), row.name, 21)
	slant(Rect2(10, 234, 198, 39), Color("121520a0"), 8, true)
	draw_coin(Vector2(37, 253))
	text_at(Vector2(67, 264), comma_number(coin_balance), 30)

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
	slant(Rect2(894, 15, 378, 43), Color("15151cdb"), 15)
	text_at(Vector2(916, 46), "LAP", 25)
	text_at(Vector2(973, 52), str(mini(3, int(race.distance / race.track.length) + 1)), 44, GOLD, true, NUMBER_FONT)
	text_at(Vector2(1011, 46), "/3", 25)
	draw_line(Vector2(1063, 20), Vector2(1054, 56), Color("e4e5e8b3"), 1.3, true)
	var c := Vector2(1098, 37)
	draw_arc(c, 11, 0, TAU, 36, WHITE, 2.4, true)
	draw_line(c, c + Vector2(3, -7), WHITE, 2, true)
	draw_line(c + Vector2(-4, -15), c + Vector2(4, -15), WHITE, 2.8, true)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -11), WHITE, 2, true)
	draw_line(c + Vector2(8, -10), c + Vector2(11, -13), WHITE, 2, true)
	text_at(Vector2(1122, 46), time_label(race.elapsed), 29)

func build_minimap() -> void:
	# Reference-shaped schematic. Race distance drives every marker along the same route.
	# This is a HUD layout model, independent of the current placeholder 3D road geometry.
	minimap_route.bake_interval = 0.5
	var knots := [
		[Vector2(1233, 87), Vector2(-12, 1), Vector2(14, -1)],
		[Vector2(1254, 109), Vector2(0, -12), Vector2(0, 15)],
		[Vector2(1234, 135), Vector2(14, 0), Vector2(-13, 0)],
		[Vector2(1206, 134), Vector2(12, -3), Vector2(-12, 2)],
		[Vector2(1188, 150), Vector2(2, -12), Vector2(-4, 14)],
		[Vector2(1172, 179), Vector2(10, -1), Vector2(-12, 1)],
		[Vector2(1147, 173), Vector2(12, 6), Vector2(-12, -5)],
		[Vector2(1110, 160), Vector2(15, 3), Vector2(-13, -7)],
		[Vector2(1100, 141), Vector2(0, 10), Vector2(0, -13)],
		[Vector2(1126, 127), Vector2(-15, 1), Vector2(14, -2)],
		[Vector2(1148, 114), Vector2(-2, 10), Vector2(4, -14)],
		[Vector2(1162, 90), Vector2(-10, 7), Vector2(12, -10)],
		[Vector2(1191, 88), Vector2(-12, -3), Vector2(15, 4)],
	]
	for knot in knots:
		minimap_route.add_point(knot[0], knot[1], knot[2])
	minimap_route.add_point(knots[0][0], knots[0][1], knots[0][2])
	minimap_points = minimap_route.get_baked_points()

func map_point(d: float) -> Vector2:
	var progress: float = fposmod(d, race.track.length) / race.track.length
	return minimap_route.sample_baked(progress * minimap_route.get_baked_length())

func draw_minimap(rows: Array[Dictionary]) -> void:
	draw_colored_polygon(minimap_points.slice(0, minimap_points.size() - 1), Color("17151eb3"))
	draw_polyline(minimap_points, Color("10101899"), 10, true)
	draw_polyline(minimap_points, Color("f1f0ef"), 5.5, true)
	var shown := 0
	for row in rows:
		if row.player:
			continue
		var p := map_point(float(row.distance))
		draw_circle(p + Vector2(0, 1), 7.5, Color("19171d"))
		draw_circle(p, 5.8, Color("ef3b57") if shown == 0 else WHITE)
		shown += 1
		if shown == 2:
			break
	var player_pos := map_point(race.distance)
	var heading := (map_point(race.distance + 5) - player_pos).angle()
	var arrow := PackedVector2Array()
	for p in [Vector2(14, 0), Vector2(-10, -9), Vector2(-6, 0), Vector2(-10, 9)]:
		arrow.append(player_pos + p.rotated(heading))
	draw_colored_polygon(arrow, GOLD)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color("342d11"), 2, true)
	var finish := map_point(0) - Vector2(8, 11)
	draw_line(finish, finish + Vector2(0, 22), WHITE, 2, true)
	draw_rect(Rect2(finish, Vector2(25, 18)), Color("202027"))
	for y in range(3):
		for x in range(4):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(finish + Vector2(x * 6, y * 6), Vector2(6, 6)), WHITE)

func draw_drift_score() -> void:
	if drift_fade <= 0:
		return
	var alpha := minf(1, drift_fade * 2)
	slant(Rect2(1124, 263, 170, 70), Color(0.07, 0.07, 0.12, alpha * 0.14), 13, true)
	text_at(Vector2(1165, 289), "DRIFT", 27, Color(WHITE, alpha), true, CAPTION_FONT)
	text_at(Vector2(1143, 319), "+%d pts" % int(drift_combo), 30, Color(GOLD, alpha), true, NUMBER_FONT)
	glow_line(PackedVector2Array([Vector2(1138, 333), Vector2(1279, 323)]), Color(CYAN, alpha), 2)

func round_button(action: String, neon: bool = false) -> void:
	var rect: Rect2 = buttons[action]
	var c := rect.get_center()
	var radius := rect.size.x / 2
	var active := held(action)
	draw_circle(c, radius, Color("12617b88") if active else Color("1a1a2240"))
	if neon:
		glow_line(arc_points(c, radius - 2, 0, TAU), Color(CYAN, 1.0 if active else 0.95), 1.8)
		draw_arc(c, radius - 4, PI * 1.15, PI * 1.90, 32, Color("9ae8ff88"), 1, true)
	else:
		draw_arc(c, radius - 1, 0, TAU, 100, Color("ffffffb8"), 1.7, true)

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
	if draw_icon(drift_texture, center + Vector2(2, 4), Vector2(51, 51), 0.12):
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
	var c := Vector2(1150, 626)
	var radius := 125.5
	var start := deg_to_rad(165)
	var end := deg_to_rad(354)
	# Smoked glass feathers into the scene instead of forming an opaque lower disc.
	draw_texture_rect(dial_backdrop, Rect2(c - Vector2(139, 139), Vector2(278, 278)), false)
	glow_line(arc_points(c, radius, start, end), Color("147fff"), 4)
	glow_line(arc_points(c, radius - 3, start, deg_to_rad(303)), Color("56dcff"), 2.8)
	glow_line(arc_points(c, radius, deg_to_rad(303), end), Color("ed3152"), 3.5)
	for i in range(29):
		var a := lerpf(start, end, i / 28.0)
		var major := i % 4 == 0
		var tint := Color("ff4964") if a > deg_to_rad(305) else Color("d7efff")
		draw_line(c + Vector2.from_angle(a) * (radius - 3), c + Vector2.from_angle(a) * (radius - (14 if major else 8)), tint, 2.8 if major else 1.3, true)
	var label_positions := [Vector2(1040, 653), Vector2(1048, 604), Vector2(1072, 569), Vector2(1115, 545), Vector2(1153, 538), Vector2(1195, 545), Vector2(1233, 570), Vector2(1239, 606)]
	for i in range(8):
		centered(label_positions[i], str(i), 18)
	var speed_kmh := int(race.speed * 3.6)
	centered(Vector2(1145, 630), str(speed_kmh), 64, WHITE, NUMBER_FONT)
	centered(Vector2(1149, 655), "km/h", 20)
	var gear := "N" if speed_kmh < 1 else str(clampi(ceili(race.speed / 13.0), 1, 6))
	var g := rounded_polygon(PackedVector2Array([Vector2(1209, 628), Vector2(1255, 628), Vector2(1243, 669), Vector2(1198, 669)]), 4)
	draw_colored_polygon(g, Color("15151b66"))
	draw_polyline(g + PackedVector2Array([g[0]]), Color("ffffffe0"), 2, true)
	centered(Vector2(1225, 663), gear, 38, WHITE, NUMBER_FONT)

func draw_nitro() -> void:
	# The reference bottle has a luminous capsule rim behind the beveled canister.
	var badge_center := Vector2(405, 659)
	var badge := PackedVector2Array()
	for i in range(65):
		var a := TAU * i / 64.0
		badge.append(badge_center + (Vector2(cos(a) * 21, sin(a) * 31)).rotated(0.5))
	draw_colored_polygon(badge, Color("10223f6b"))
	glow_line(badge, Color("058dffcc"), 2.5)
	glow_line(badge, Color("31dfffbb"), 1)
	bottle(badge_center, 0.78)
	draw_string_outline(NUMBER_FONT, Vector2(443, 656), "NITRO", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 4, Color("2bd6ff40"))
	text_at(Vector2(443, 656), "NITRO", 28, WHITE, true, NUMBER_FONT)
	var rim := rounded_polygon(PackedVector2Array([Vector2(442, 661), Vector2(847, 661), Vector2(835, 691), Vector2(430, 691)]), 4)
	draw_colored_polygon(rim, Color("12131ecc"))
	draw_polyline(rim + PackedVector2Array([rim[0]]), Color("171a29b3"), 6, true)
	draw_polyline(rim + PackedVector2Array([rim[0]]), Color("bac0ce99"), 2.5, true)
	draw_polyline(PackedVector2Array([Vector2(443, 663), Vector2(842, 663)]), Color("e1edff73"), 1, true)
	var charge := clampf(race.nitro / 100.0, 0, 1)
	if charge > 0:
		var right := 438 + 395 * charge
		glow_line(PackedVector2Array([Vector2(435, 684), Vector2(right, 684)]), Color("06cbff80"), 4)
	for i in range(9):
		var cell_fill := clampf(charge * 9 - i, 0, 1)
		if cell_fill <= 0:
			break
		var x := 445.0 + i * 43
		var width := 41.0 * cell_fill
		var points := PackedVector2Array([Vector2(x, 667), Vector2(x + width, 667), Vector2(x + width - 8, 684), Vector2(x - 8, 684)])
		draw_polygon(points, PackedColorArray([Color("84fbff"), Color("b0ffff"), Color("04b7ee"), Color("00d4ff")]))
		draw_polyline(PackedVector2Array([points[3], points[2]]), Color("57efffff"), 1.2, true)

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
