extends RefCounted
# 밝은 해안 메뉴의 공용 색·패널·번역 글자 맞춤. 주행 HUD의 대비 색과 분리한다.
const INK := Color("f8fafb")
const MUTED := Color("d1e0e9")
const AQUA := Color("a7cce0")
const TEAL := Color("efce82")
const CORAL := Color("bd6e58")
const YELLOW := Color("dfbd69")
const PAPER := Color("2e5269")
const CANVAS := Color("5c91af")
const SOFT := Color("3b6781")
const BORDER := Color("7d9cae")
const Art = preload("res://scripts/ui/rev3_art.gd")


static func points(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array(
		[
			p + Vector2(cut, 0),
			Vector2(e.x, p.y),
			e - Vector2(0, cut),
			e - Vector2(cut, 0),
			Vector2(p.x, e.y),
			p + Vector2(0, cut)
		]
	)


static func panel(hud: Control, rect: Rect2, fill: Color = PAPER, selected: bool = false, cut: float = 12.0) -> void:
	Art.draw_panel(hud, rect, fill == YELLOW, cut)
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = YELLOW
		style.set_border_width_all(3)
		style.set_corner_radius_all(16)
		hud.draw_style_box(style, rect)


static func fit_size(hud: Control, value: String, width: float, preferred: int, minimum: int = 22) -> int:
	var font_size := preferred
	while font_size > minimum and hud.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size


static func layout_text(hud: Control, key: String, width: float, preferred: int, minimum: int = 22) -> Dictionary:
	if width < hud.FONT.get_string_size("…", HORIZONTAL_ALIGNMENT_LEFT, -1, minimum).x:
		return {"text": "", "size": minimum}
	var value: String = hud.race.tr(key)
	var fitted := fit_size(hud, value, width, preferred, minimum)
	# 원문 키는 유지하고 긴 번역은 최소 크기 뒤 말줄임한다. 이미지에 문자를 굽지 않는다.
	if hud.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		while (
			not value.is_empty()
			and hud.FONT.get_string_size(value + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width
		):
			value = value.left(value.length() - 1)
		value += "…"
	return {"text": value, "size": fitted}


static func label(
	hud: Control,
	rect: Rect2,
	key: String,
	font_size: int = 28,
	color: Color = INK,
	centered: bool = false,
	minimum: int = 22
) -> void:
	var layout := layout_text(hud, key, rect.size.x, font_size, minimum)
	hud.menu_text.draw(rect, layout.text, layout.size, color, centered)


static func button(hud: Control, rect: Rect2, key: String, fill: Color = SOFT, font_size: int = 28) -> void:
	Art.draw_panel(hud, rect, fill == YELLOW)
	label(hud, rect.grow(-12), key, font_size, INK, true)


static func canvas(hud: Control) -> void:
	hud.rev3.art.background(hud, "start", hud.top_hud_bounds())


static func cover(hud: Control, texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var scale_factor := minf(source.size.x / rect.size.x, source.size.y / rect.size.y)
	var cropped := rect.size * scale_factor
	source.position = (source.size - cropped) * .5
	source.size = cropped
	hud.draw_texture_rect_region(texture, rect, source, tint)
