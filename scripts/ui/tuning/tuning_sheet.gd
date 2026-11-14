extends Control
# 팝업 밖 터치도 전체 안전 영역에서 막는다. 배경 메뉴의 버튼이 비율에 따라 노출돼도 작동하지 않는다.
signal confirmed
const Layout = preload("res://scripts/ui/menu_layout.gd")
var blocker: Control


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	blocker = Control.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	var safe := Layout.safe_rect(get_viewport_rect().size)
	var scale_factor := Layout.scale_for(safe)
	blocker.position = (safe.position - Layout.origin_for(safe)) / scale_factor
	blocker.size = safe.size / scale_factor
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(blocker.position, blocker.size), Color(.08, .18, .25, .38))
