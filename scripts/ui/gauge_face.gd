extends Node2D
# Render the unchanging dial once. Live RPM, speed and gear stay sharp in the HUD.
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
var backdrop: Texture2D


func arc(center: Vector2, radius: float, start: float, end: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(81):
		out.append(center + Vector2.from_angle(lerpf(start, end, i / 80.0)) * radius)
	return out


func glow(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, Color(color, 0.08), width * 5, true)
	draw_polyline(points, Color(color, 0.18), width * 2.5, true)
	draw_polyline(points, color, width, true)


func text_at(p: Vector2, value: String, size_px: int, color: Color) -> void:
	draw_string_outline(
		FONT,
		p + Vector2(0.5, 1.5),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size_px,
		2,
		Color(0.02, 0.02, 0.04, color.a * 0.38)
	)
	draw_string(FONT, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func centered(p: Vector2, value: String, size_px: int, color: Color) -> void:
	text_at(
		p - Vector2(FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5, 0),
		value,
		size_px,
		color
	)


func _draw() -> void:
	var c := Vector2(150, 150)
	var radius := 125.5
	var start := deg_to_rad(165)
	var end := deg_to_rad(354)
	draw_texture_rect(backdrop, Rect2(c - Vector2(139, 139), Vector2(278, 278)), false)
	glow(arc(c, radius, start, end), Color("147fff"), 4)
	glow(arc(c, radius - 3, start, deg_to_rad(303)), Color("56dcff"), 2.8)
	glow(arc(c, radius, deg_to_rad(303), end), Color("ed3152"), 3.5)
	for i in range(29):
		var a := lerpf(start, end, i / 28.0)
		var major := i % 4 == 0
		draw_line(
			c + Vector2.from_angle(a) * (radius - 3),
			c + Vector2.from_angle(a) * (radius - (14 if major else 8)),
			Color("ff4964") if a > deg_to_rad(305) else Color("d7efff"),
			2.8 if major else 1.3,
			true
		)
	text_at(Vector2(119, 105), "RPM", 12, Color("9ebfcd"))
	var positions := [
		Vector2(40, 177),
		Vector2(48, 128),
		Vector2(72, 93),
		Vector2(115, 69),
		Vector2(153, 62),
		Vector2(195, 69),
		Vector2(233, 94),
		Vector2(239, 130)
	]
	for i in range(8):
		centered(positions[i], str(i), 18, Color("f6f7fa"))
	centered(Vector2(149, 179), "km/h", 20, Color("f6f7fa"))
	var gear := PackedVector2Array([Vector2(209, 152), Vector2(255, 152), Vector2(243, 193), Vector2(198, 193)])
	draw_colored_polygon(gear, Color("15151b66"))
	draw_polyline(gear + PackedVector2Array([gear[0]]), Color("ffffffe0"), 2, true)
