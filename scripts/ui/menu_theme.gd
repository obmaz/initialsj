extends RefCounted
# 밝은 해안 메뉴의 공용 색·패널·번역 글자 맞춤. 주행 HUD의 대비 색과 분리한다.
const INK := Color("142b49")
const MUTED := Color("486378")
const AQUA := Color("17d5d6")
const TEAL := Color("076e79")
const CORAL := Color("fb646b")
const YELLOW := Color("ffdf45")
const PAPER := Color("fffdf7")
const CANVAS := Color("edf7fa")
const SOFT := Color("e1f5f5")
const BORDER := Color("406b89")
const HEADER_ART := "res://assets/ui/pre_race/header.png"
const PRIMARY_ART := "res://assets/ui/pre_race/primary.png"


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
	preload("res://scripts/ui/pre_race_art.gd").draw_frame(hud, rect, "panel")
	if selected:
		var outline := points(rect.grow(-3), minf(cut, 10))
		outline.append(outline[0])
		hud.draw_polyline(outline, AQUA, 3, true)


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
	preload("res://scripts/ui/pre_race_art.gd").draw_frame(hud, rect, "primary" if fill == YELLOW else "button")
	label(hud, rect.grow(-12), key, font_size, INK, true)


static func canvas(hud: Control) -> void:
	hud.draw_rect(Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()), CANVAS)
	hud.draw_rect(Rect2(0, 0, 1280, 106), PAPER)
	hud.draw_texture_rect(hud.menus.art(HEADER_ART), Rect2(310, 19, 615, 76), false)
	hud.draw_line(Vector2(32, 105), Vector2(1248, 105), BORDER, 1, true)
	# 시안의 청록·코랄 속도 줄무늬를 벡터 장식으로 공유한다.
	hud.draw_colored_polygon(
		PackedVector2Array([Vector2(1080, 16), Vector2(1230, 16), Vector2(1160, 90), Vector2(1010, 90)]), AQUA
	)
	hud.draw_colored_polygon(
		PackedVector2Array([Vector2(1240, 16), Vector2(1260, 16), Vector2(1260, 90), Vector2(1170, 90)]), CORAL
	)


static func cover(hud: Control, texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var scale_factor := minf(source.size.x / rect.size.x, source.size.y / rect.size.y)
	var cropped := rect.size * scale_factor
	source.position = (source.size - cropped) * .5
	source.size = cropped
	hud.draw_texture_rect_region(texture, rect, source, tint)
