extends Control
# 기본 OS 창의 최소 크기 대신 메뉴의 안전 영역·배율 안에서 대화창을 표시한다.
signal confirmed


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(.08, .18, .25, .6))
