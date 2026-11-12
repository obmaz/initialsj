extends RefCounted
# 메뉴 글자는 실제Label로 표시한다. 고정 풀을 재사용해 프레임마다 노드를 만들지 않는다.
const CAPACITY := 64
var hud: Control
var labels: Array[Label] = []
var used := 0


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
	label.position = hud.ui_offset() + rect.position * hud.ui_scale()
	label.size = rect.size
	label.scale = Vector2.ONE * hud.ui_scale()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.visible = true


func finish() -> void:
	for index in range(used, labels.size()):
		if labels[index].visible:
			labels[index].visible = false
