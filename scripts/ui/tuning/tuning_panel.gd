extends Control
# 시안의 잘린 모서리·얇은 테두리. 입력은 위에 놓인 네이티브 컨트롤이 소유한다.
var fill := Color.WHITE
var bevel := 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var cut := minf(bevel, minf(size.x, size.y) * .3)
	var points := PackedVector2Array(
		[
			Vector2(cut, 0),
			Vector2(size.x, 0),
			Vector2(size.x, size.y - cut),
			Vector2(size.x - cut, size.y),
			Vector2(0, size.y),
			Vector2(0, cut)
		]
	)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, .9), 2, true)
