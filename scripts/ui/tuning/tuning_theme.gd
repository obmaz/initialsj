extends RefCounted
# 밝은 해안 커스텀 샵의 색·서체·입력 상태를 네이티브 컨트롤에 일관되게 적용한다.
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const INK := Color("f8fafb")
const MUTED := Color("d1e0e9")
const AQUA := Color("dfbd69")
const CORAL := Color("bd6e58")
const YELLOW := Color("dfbd69")
const PAPER := Color("355d77")
const FONT = preload("res://assets/ui/rev3/fonts/interface_font.tres")


static func create_panel_style(fill: Color, border: Color, width: int = 1, radius: int = 3) -> StyleBoxFlat:
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
	result.default_font_size = 23
	for type in ["Button", "OptionButton", "ColorPickerButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var fill := Color("4a7390") if state == "hover" else PAPER
			var border := AQUA if state in ["pressed", "hover", "focus"] else Color("7b9aae")
			var style := create_panel_style(fill, border, 2 if state in ["pressed", "focus"] else 1)
			style.skew = Vector2.ZERO
			if state == "focus":
				style.bg_color = Color.TRANSPARENT
			if state == "disabled":
				style.bg_color = Color("43647a")
			result.set_stylebox(state, type, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, Color("adc0cc"))
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "PopupMenu", INK)
	result.set_stylebox("panel", "PopupMenu", create_panel_style(PAPER, Color("7b9aae")))
	result.set_stylebox("panel", "PopupPanel", create_panel_style(PAPER, AQUA, 2, 12))
	for state in ["normal", "read_only", "focus"]:
		result.set_stylebox(state, "LineEdit", create_panel_style(PAPER, AQUA if state == "focus" else Color("7b9aae")))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_uneditable_color", "LineEdit", MUTED)
	result.set_stylebox("panel", "AcceptDialog", create_panel_style(PAPER, AQUA, 2, 12))
	result.set_color("font_color", "AcceptDialog", INK)
	return result


static func apply_accent_style(button: Button, fill: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := fill.lightened(.12) if state == "hover" else (fill.darkened(.08) if state == "pressed" else fill)
		if state == "disabled":
			color = fill.lightened(.35)
		var style := create_panel_style(color, color)
		style.skew = Vector2.ZERO
		button.add_theme_stylebox_override(state, style)


static func apply_swatch_style(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", create_panel_style(color, Color("adbcca"), 2, 48))
	button.add_theme_stylebox_override("hover", create_panel_style(color.lightened(.08), INK, 2, 48))
	button.add_theme_stylebox_override("pressed", create_panel_style(color, AQUA, 5, 48))
	var focus := create_panel_style(Color.TRANSPARENT, AQUA, 3, 48)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
