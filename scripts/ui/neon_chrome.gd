extends RefCounted
# 생성형 기준의 글자 없는 금속·네온 장식을 2D 벡터로 그린다.
const CYAN := Color("24dfff")
const GOLD := Color("ffd875")
const NAVY := Color("071a29f5")


static func points(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var c := minf(cut, minf(rect.size.x, rect.size.y) * .45)
	return PackedVector2Array(
		[
			p + Vector2(c, 0),
			Vector2(e.x - c, p.y),
			Vector2(e.x, p.y + c),
			e - Vector2(0, c),
			e - Vector2(c, 0),
			Vector2(p.x + c, e.y),
			Vector2(p.x, e.y - c),
			p + Vector2(0, c)
		]
	)


static func panel(
	canvas: CanvasItem, rect: Rect2, accent: Color = CYAN, cut: float = 12.0, fill: Color = NAVY, width: float = 2.0
) -> void:
	var polygon := points(rect, cut)
	var colors := PackedColorArray()
	for point in polygon:
		var ratio := (point.y - rect.position.y) / maxf(1, rect.size.y)
		var color := fill.lightened(.045).lerp(fill.darkened(.15), ratio)
		color.a = fill.a
		colors.append(color)
	canvas.draw_polygon(polygon, colors)
	polygon.append(polygon[0])
	canvas.draw_polyline(polygon, Color(accent, .10), width + 7, true)
	canvas.draw_polyline(polygon, accent, width, true)
	var inset := points(rect.grow(-4), maxf(2, cut - 2))
	inset.append(inset[0])
	canvas.draw_polyline(inset, Color(accent, .24), 1, true)
	canvas.draw_line(
		rect.position + Vector2(cut + 4, 2),
		Vector2(rect.end.x - cut - 4, rect.position.y + 2),
		Color("c6faffb0"),
		1,
		true
	)


static func star(canvas: CanvasItem, center: Vector2, radius: float, color: Color = GOLD) -> void:
	var polygon := PackedVector2Array()
	for i in range(10):
		polygon.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * radius * (1.0 if i % 2 == 0 else .44))
	canvas.draw_colored_polygon(polygon, color)


static func trophy(canvas: CanvasItem, center: Vector2, size: float, color: Color = GOLD) -> void:
	var cup := PackedVector2Array()
	for point in [Vector2(-.42, -.38), Vector2(.42, -.38), Vector2(.31, .1), Vector2(0, .28), Vector2(-.31, .1)]:
		cup.append(center + point * size)
	canvas.draw_colored_polygon(cup, color)
	canvas.draw_rect(Rect2(center + Vector2(-.055, .19) * size, Vector2(.11, .28) * size), color)
	canvas.draw_rect(Rect2(center + Vector2(-.28, .44) * size, Vector2(.56, .08) * size), color)
	for side in [-1, 1]:
		var handle := PackedVector2Array()
		for point in [Vector2(.40, -.30), Vector2(.65, -.30), Vector2(.57, .02), Vector2(.32, .13)]:
			handle.append(center + Vector2(point.x * side, point.y) * size)
		canvas.draw_polyline(handle, color, size * .065, true)
	star(canvas, center + Vector2(0, -.12) * size, size * .14, Color("6b431c"))


static func lightning(canvas: CanvasItem, center: Vector2, size: float, color: Color = CYAN) -> void:
	var polygon := PackedVector2Array()
	for point in [
		Vector2(.12, -.5),
		Vector2(-.34, .08),
		Vector2(-.03, .03),
		Vector2(-.15, .5),
		Vector2(.36, -.14),
		Vector2(.04, -.08)
	]:
		polygon.append(center + point * size)
	canvas.draw_colored_polygon(polygon, color)
