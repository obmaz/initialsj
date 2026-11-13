extends RefCounted
# 메뉴 글자는 실제Label로 표시한다. 고정 풀을 재사용해 프레임마다 노드를 만들지 않는다.
const CAPACITY := 64
var hud: Control
var labels: Array[Label] = []
var used := 0
var content_transform := Transform2D.IDENTITY


func _init(owner: Control) -> void:
	hud = owner


func prepare() -> void:
	if not labels.is_empty():
		return
	for index in range(CAPACITY):
		var label := Label.new()
		label.name = "MenuText%d" % index
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.visible = false
		label.add_theme_font_override("font", hud.FONT)
		label.add_theme_constant_override("outline_size", 0)
		hud.add_child(label)
		labels.append(label)


func begin() -> void:
	used = 0


func draw(rect: Rect2, value: String, font_size: int, color: Color, centered: bool) -> void:
	assert(used < labels.size(), "메뉴 글자 풀 상한을 늘리기 전에 화면 밀도를 검토한다")
	var label := labels[used]
	used += 1
	if label.text != value:
		label.text = value
	if label.get_theme_font_size("font_size") != font_size:
		label.add_theme_font_size_override("font_size", font_size)
	if label.get_theme_color("font_color") != color:
		label.add_theme_color_override("font_color", color)
	label.position = hud.ui_offset() + (content_transform * rect.position) * hud.ui_scale()
	label.size = rect.size
	label.scale = content_transform.get_scale() * hud.ui_scale()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.max_lines_visible = 1
	label.visible = true


func finish() -> void:
	for index in range(used, labels.size()):
		if labels[index].visible:
			labels[index].visible = false


func draw_wrapped(rect: Rect2, value: String, font_size: int, color: Color) -> void:
	# 고정 풀 Label의 줄 수 캐시와 무관하게 두 줄을 각각 배치한다.
	var lines := ["", ""]
	var second := false
	for word in value.split(" "):
		var candidate: String = word if lines[0].is_empty() else lines[0] + " " + word
		if (
			not second
			and hud.FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect.size.x
		):
			lines[0] = candidate
		else:
			second = true
			lines[1] += ("" if lines[1].is_empty() else " ") + word
	for i in range(2):
		draw(
			Rect2(rect.position + Vector2(0, i * rect.size.y / 2), Vector2(rect.size.x, rect.size.y / 2)),
			lines[i],
			font_size,
			color,
			false
		)
