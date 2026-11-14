extends Control
# 팝업의 실질 입력은 자식 네이티브 컨트롤이 맡는다.
const Art = preload("res://scripts/ui/rev3_art.gd")
var fill := Color.WHITE
var bevel := 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	Art.draw_panel(self, Rect2(Vector2.ZERO, size), fill == Art.CORAL, 24)
