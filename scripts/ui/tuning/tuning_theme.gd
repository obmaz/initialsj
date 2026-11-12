extends RefCounted
# 밝은 해안 커스텀 샵의 색·서체·입력 상태를 네이티브 컨트롤에 일관되게 적용한다.
const INK := Color("142b49")
const MUTED := Color("65778a")
const AQUA := Color("17d5d6")
const CORAL := Color("fb646b")
const YELLOW := Color("ffdf45")
const PAPER := Color("f6fbff")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")


static func create_panel_style(fill: Color, border: Color, width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 18
	for type in ["Button", "OptionButton", "ColorPickerButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var fill := AQUA if state == "pressed" else (Color("e3f8fa") if state == "hover" else PAPER)
			var border := AQUA if state in ["pressed", "hover", "focus"] else Color("c3ceda")
			var style := create_panel_style(fill, border, 2 if state in ["pressed", "focus"] else 1)
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
			if state == "disabled":
				style.bg_color = Color("e8eef2")
			result.set_stylebox(state, type, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, Color("8191a1"))
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "PopupMenu", INK)
	result.set_stylebox("panel", "PopupMenu", create_panel_style(PAPER, Color("c3ceda")))
	result.set_stylebox("panel", "PopupPanel", create_panel_style(PAPER, AQUA, 2, 12))
	for state in ["normal", "read_only", "focus"]:
		result.set_stylebox(state, "LineEdit", create_panel_style(PAPER, AQUA if state == "focus" else Color("c3ceda")))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_uneditable_color", "LineEdit", MUTED)
	result.set_stylebox("panel", "AcceptDialog", create_panel_style(PAPER, AQUA, 2, 12))
	result.set_color("font_color", "AcceptDialog", INK)
	return result


static func apply_accent_style(button: Button, fill: Color) -> void:
	button.add_theme_stylebox_override("normal", create_panel_style(fill, fill))
	button.add_theme_stylebox_override("hover", create_panel_style(fill.lightened(.12), INK))
	button.add_theme_stylebox_override("pressed", create_panel_style(fill.darkened(.08), INK, 2))


static func apply_swatch_style(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", create_panel_style(color, Color("adbcca"), 1, 24))
	button.add_theme_stylebox_override("hover", create_panel_style(color, INK, 2, 24))
	button.add_theme_stylebox_override("pressed", create_panel_style(color, INK, 4, 24))
	var focus := create_panel_style(Color.TRANSPARENT, AQUA, 2, 24)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
