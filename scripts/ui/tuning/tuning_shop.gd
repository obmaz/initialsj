extends CanvasLayer
const VehicleFactory = preload("res://scripts/vehicles/vehicle_factory.gd")
const VehicleCatalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const CustomizationStore = preload("res://scripts/vehicles/customization_store.gd")
const Effects = preload("res://scripts/vehicles/effect_items.gd")
const Customization = preload("res://scripts/vehicles/vehicle_customization.gd")
const MenuLayout = preload("res://scripts/ui/menu_layout.gd")
const TuningTheme = preload("res://scripts/ui/tuning/tuning_theme.gd")
const BACKGROUND_PATH := "res://assets/ui/backgrounds/tuning_bay.png"
const DESIGN_SIZE := Vector2(1280, 720)
const PAINT_COLORS := [
	"edf1ef", "20cbd0", "fb686e", "ffdc48", "173454", "b7bec4", "777e89", "509bed", "aa80d3", "252c35"
]
const LIVERY_LABELS := ["ORIGINAL", "HERITAGE STRIPES", "COAST WAVES", "CIRCUIT GRAPHIC"]
const WHEEL_LABELS := ["ORIGINAL WHEELS", "FORGED 5-SPOKE", "SPLIT SPOKE"]
const WING_LABELS := ["ORIGINAL AERO", "LOW DUCKTAIL", "GT REAR WING", "NO WING"]
var race: Node3D
var content_root: Control
var options_panel: Control
var options_scroll: ScrollContainer
var preview_viewport: SubViewport
var preview_camera: Camera3D
var preview_display: TextureRect
var preview_car: Node3D
var save_status_label: Label
var apply_button: Button
var compare_button: Button
var boost_button: Button
var draft_customization: Dictionary = {}
var saved_customization: Dictionary = {}
var selected_tab := 0
var tab_buttons: Array[Button] = []
var is_comparing := false
var boost_preview_active := false
var effect_preview_time := 0.0
var vehicle_index := 0
var mouse_drag_active := false
var active_touch_index := -1
var discard_dialog: Control
var color_sheet: Control
var custom_picker: ColorPicker
var custom_color_key := "paint"
var discard_keep: Button
var color_done: Button
var previous_focus: Control
var modal_focus_modes: Dictionary = {}


func _ready() -> void:
	layer = 30
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color("e6f5fa")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	content_root = Control.new()
	content_root.size = DESIGN_SIZE
	content_root.theme = TuningTheme.create_theme()
	add_child(content_root)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load(BACKGROUND_PATH)
	art.size = DESIGN_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(art)
	create_preview()
	build_layout()
	options_scroll = ScrollContainer.new()
	options_scroll.position = Vector2(34, 194)
	options_scroll.size = Vector2(356, 416)
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_root.add_child(options_scroll)
	options_panel = Control.new()
	options_scroll.add_child(options_panel)
	build_sheets()
	rebuild_options()
	refresh_customization()


func create_preview() -> void:
	# 배경은 샵 인스턴스만 소유하고, 독립 뷰포트는 변경·회전·시연 중에만 갱신한다.
	var shadow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(.04, .1, .16, .32), Color(.04, .1, .16, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5, .5)
	texture.fill_to = Vector2(1, .5)
	texture.width = 256
	texture.height = 64
	shadow.texture = texture
	shadow.position = Vector2(520, 480)
	shadow.size = Vector2(700, 72)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(shadow)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(720, 344) if race.lite_graphics else Vector2i(1080, 516)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.msaa_3d = Viewport.MSAA_DISABLED if race.lite_graphics else Viewport.MSAA_2X
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	content_root.add_child(preview_viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.TRANSPARENT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4f3ff")
	environment.ambient_light_energy = .65
	world.environment = environment
	preview_viewport.add_child(world)
	for pose in [Vector3(-40, -35, 0), Vector3(-15, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = pose
		light.light_energy = 1.1 if pose.y < 0 else .4
		preview_viewport.add_child(light)
	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(-4.8, 1.6, -5.4)
	preview_camera.fov = 21
	preview_viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0, .65, 0))
	preview_car = VehicleFactory.create(vehicle_index)
	preview_viewport.add_child(preview_car)
	race.passport.apply_car(preview_car, vehicle_index)
	preview_car.reduced_motion = race.motion_reduced
	preview_car.effects_quality = race.player.effects_quality
	preview_display = TextureRect.new()
	preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_display.position = Vector2(385, 176)
	preview_display.texture = preview_viewport.get_texture()
	preview_display.size = Vector2(895, 350)
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_display.gui_input.connect(drag_preview)
	content_root.add_child(preview_display)


func build_layout() -> void:
	add_panel(Rect2(0, 0, 1280, 106), TuningTheme.PAPER)
	var back := add_button("‹ BACK", MenuLayout.BACK, request_close, 28)
	back.name = "Back"
	call_deferred("focus_back", back)
	var title := add_label("COAST CUSTOMS", Rect2(330, 20, 600, 68), 40)
	title.name = "Title"
	title.add_theme_font_override("font", preload("res://assets/fonts/Roboto-BlackItalic.ttf"))
	var name_label := add_label(str(VehicleCatalog.spec(vehicle_index).name), Rect2(958, 20, 276, 68), 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(5):
		var tab_button := add_button(
			["PAINT", "LIVERY", "WHEELS", "REAR WING", "EFFECTS"][i],
			Rect2(34 + i * 244, 106, 232, 80),
			func():
				selected_tab = i
				rebuild_options(),
			24
		)
		var selected_style := TuningTheme.create_panel_style(TuningTheme.AQUA, Color.WHITE, 2)
		tab_button.add_theme_stylebox_override("pressed", selected_style)
		tab_button.toggle_mode = true
		tab_buttons.append(tab_button)
	add_panel(Rect2(22, 194, 368, 416), Color("fffffff0"))
	add_panel(Rect2(404, 530, 852, 80), Color("fffffff2"))
	for i in range(3):
		add_button(["FRONT", "SIDE", "REAR"][i], Rect2(415 + i * 126, 530, 116, 80), func(): set_view(i), 21)
	add_label("DRAG TO ROTATE", Rect2(808, 544, 196, 52), 19, TuningTheme.MUTED)
	boost_button = add_button("» BOOST", Rect2(1026, 530, 214, 80), toggle_boost, 23)
	boost_button.toggle_mode = true
	add_panel(Rect2(0, 622, 1280, 98), Color("fffffff8"))
	add_button("RESET", Rect2(30, 628, 160, 80), reset_draft, 23)
	compare_button = add_button("COMPARE", Rect2(206, 628, 178, 80), toggle_compare, 23)
	compare_button.toggle_mode = true
	add_button("CANCEL", Rect2(400, 628, 142, 80), request_close, 23)
	save_status_label = add_label("", Rect2(562, 641, 412, 54), 22)
	save_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_button = add_button("APPLY  »", Rect2(1000, 628, 250, 80), apply_changes, 36)
	TuningTheme.apply_accent_style(apply_button, TuningTheme.YELLOW)


func add_panel(rect: Rect2, color: Color) -> void:
	var node := preload("res://scripts/ui/tuning/tuning_panel.gd").new()
	node.position = rect.position
	node.size = rect.size
	node.fill = color
	content_root.add_child(node)


func add_label(
	text: String, rect: Rect2, size_px: int, color: Color = TuningTheme.INK, parent: Control = null
) -> Label:
	var node := Label.new()
	node.text = text
	node.set_meta("tuning_font_size", size_px)
	node.position = rect.position
	node.size = rect.size
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else content_root).add_child(node)
	return node


func add_button(text: String, rect: Rect2, action: Callable, size_px: int = 18, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text
	node.set_meta("tuning_font_size", size_px)
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size_px)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.tooltip_text = text
	node.pressed.connect(action)
	(parent if parent != null else content_root).add_child(node)
	return node


func build_color_options(key: String, title: String, y: float, colors: Array) -> void:
	add_label(title, Rect2(5, y, 234, 80), 24, TuningTheme.INK, options_panel)
	var picker := add_button("+", Rect2(264, y, 80, 80), func(): open_custom_color(key), 32, options_panel)
	picker.set_meta("color_key", key)
	picker.tooltip_text = "CUSTOM COLOR"
	TuningTheme.apply_swatch_style(picker, Color(draft_customization[key]))
	for i in range(colors.size()):
		var color := Color(colors[i])
		var node := add_button(
			"",
			Rect2((i % 4) * 88, y + 88 + (i / 4) * 88, 80, 80),
			func(): set_customization_value(key, colors[i]),
			14,
			options_panel
		)
		node.toggle_mode = true
		node.tooltip_text = "#" + str(colors[i]).to_upper()
		node.set_meta("selection_key", key)
		node.set_meta("selection_value", colors[i])
		TuningTheme.apply_swatch_style(node, color)


func rebuild_options() -> void:
	for i in range(tab_buttons.size()):
		tab_buttons[i].set_pressed_no_signal(i == selected_tab)
	for child in options_panel.get_children():
		child.free()
	options_scroll.scroll_vertical = 0
	options_panel.custom_minimum_size = Vector2(
		344, 854 if selected_tab == 0 else (720 if selected_tab == 4 else (570 if selected_tab == 2 else 454))
	)
	if selected_tab == 0:
		build_color_options("paint", "BODY COLOR", 0, PAINT_COLORS)
		build_color_options("secondary", "ACCENT COLOR", 370, PAINT_COLORS)
		add_label("FINISH", Rect2(4, 724, 344, 30), 22, TuningTheme.INK, options_panel)
		for i in range(3):
			add_choice_button(["GLOSS", "MATTE", "METAL"][i], Rect2(i * 116, 762, 112, 80), "finish", i, 20)
	elif selected_tab == 1:
		for i in range(4):
			var choice := add_choice_button(LIVERY_LABELS[i], Rect2(0, i * 109, 344, 94), "livery", i, 23)
			if i > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = load(Customization.ATLAS)
				atlas.region = Rect2(
					Vector2(vehicle_index * atlas.atlas.get_width() / 4.0, (i - 1) * atlas.atlas.get_height() / 3.0),
					Vector2(atlas.atlas.get_width() / 4.0, atlas.atlas.get_height() / 3.0)
				)
				choice.icon = atlas
				choice.expand_icon = true
				choice.add_theme_constant_override("icon_max_width", 56)
	elif selected_tab == 2:
		for i in range(3):
			add_choice_button(WHEEL_LABELS[i], Rect2(0, i * 92, 344, 80), "wheel", i, 23)
		build_color_options("rim", "RIM COLOR", 280, ["b7bec4", "dfb65a", "252c35", "edf1ef", "20cbd0"])
	elif selected_tab == 3:
		for i in range(4):
			add_choice_button(WING_LABELS[i], Rect2(0, i * 109, 344, 94), "wing", i, 23)
	else:
		var slots := add_label("", Rect2(4, 0, 336, 50), 24, TuningTheme.INK, options_panel)
		slots.name = "EffectSlots"
		for i in range(Effects.IDS.size()):
			var id: String = Effects.IDS[i]
			var button := add_button(
				Effects.LABELS[i], Rect2(0, 64 + i * 158, 344, 76), func(): toggle_effect(id), 25, options_panel
			)
			button.toggle_mode = true
			button.set_meta("effect_id", id)
			var help := add_label(
				Effects.HELP[i] if Effects.supported(id, vehicle_index) else "Not available for this vehicle.",
				Rect2(6, 142 + i * 158, 330, 72),
				20,
				TuningTheme.MUTED,
				options_panel
			)
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh_customization()


func add_choice_button(text: String, rect: Rect2, key: String, value: int, size_px: int = 18) -> Button:
	var node := add_button(text, rect, func(): set_customization_value(key, value), size_px, options_panel)
	node.toggle_mode = true
	node.set_meta("selection_key", key)
	node.set_meta("selection_value", value)
	return node


func set_customization_value(key: String, value: Variant) -> void:
	draft_customization[key] = value
	is_comparing = false
	refresh_customization()


func refresh_customization() -> void:
	draft_customization = CustomizationStore.sanitize(draft_customization, vehicle_index)
	for child in options_panel.get_children():
		if child is Button and child.has_meta("selection_key"):
			child.set_pressed_no_signal(
				draft_customization[child.get_meta("selection_key")] == child.get_meta("selection_value")
			)
		elif child is Button and child.has_meta("effect_id"):
			var id: String = child.get_meta("effect_id")
			var equipped: bool = id in draft_customization.effects
			child.set_pressed_no_signal(equipped)
			child.disabled = (
				not Effects.supported(id, vehicle_index)
				or (not equipped and draft_customization.effects.size() >= Effects.slots(vehicle_index))
			)
		elif child.has_meta("color_key"):
			var color := Color(draft_customization[child.get_meta("color_key")])
			TuningTheme.apply_swatch_style(child, color)
			child.add_theme_color_override("font_color", TuningTheme.INK if color.get_luminance() > .4 else Color.WHITE)
	var count_label := options_panel.get_node_or_null("EffectSlots") as Label
	if count_label != null:
		count_label.text = (
			tr("EFFECT SLOTS %d / %d") % [draft_customization.effects.size(), Effects.slots(vehicle_index)]
		)
	var data: Dictionary = saved_customization if is_comparing else draft_customization
	Customization.apply(preview_car, data, vehicle_index)
	effect_preview_time = 0
	preview_car.set_presentation_rotation(Vector3.ZERO)
	compare_button.set_pressed_no_signal(is_comparing)
	apply_button.disabled = draft_customization == saved_customization
	save_status_label.text = (
		"SAVED LOOK"
		if is_comparing
		else ("UNSAVED CHANGES" if draft_customization != saved_customization else "LOOK APPLIED")
	)
	save_status_label.add_theme_color_override(
		"font_color",
		TuningTheme.CORAL if draft_customization != saved_customization and not is_comparing else TuningTheme.MUTED
	)
	fit_translated_text()
	request_preview_render()


func toggle_effect(id: String) -> void:
	var equipped: Array = draft_customization.effects.duplicate()
	if id in equipped:
		equipped.erase(id)
	elif Effects.supported(id, vehicle_index) and equipped.size() < Effects.slots(vehicle_index):
		equipped.append(id)
	set_customization_value("effects", equipped)


func reset_draft() -> void:
	draft_customization = CustomizationStore.defaults(vehicle_index)
	is_comparing = false
	rebuild_options()


func toggle_compare() -> void:
	is_comparing = not is_comparing
	refresh_customization()


func toggle_boost() -> void:
	effect_preview_time = 0
	preview_car.set_presentation_rotation(Vector3.ZERO)
	boost_preview_active = not boost_preview_active
	boost_button.set_pressed_no_signal(boost_preview_active)


func set_view(index: int) -> void:
	preview_car.rotation.y = 0
	preview_camera.position = [Vector3(0, 1.6, -6.4), Vector3(-6.4, 1.6, 0), Vector3(0, 1.6, 6.4)][index]
	preview_camera.look_at(Vector3(0, .65, 0))
	request_preview_render()


func request_preview_render() -> void:
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func drag_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_drag_active = event.pressed
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_index < 0:
			active_touch_index = event.index
		elif not event.pressed and event.index == active_touch_index:
			active_touch_index = -1
	if (
		(event is InputEventMouseMotion and mouse_drag_active)
		or (event is InputEventScreenDrag and event.index == active_touch_index)
	):
		preview_car.rotation.y += event.relative.x * .008
		request_preview_render()


func _process(delta: float) -> void:
	var safe := MenuLayout.safe_rect(get_viewport().get_visible_rect().size)
	content_root.scale = Vector2.ONE * MenuLayout.scale_for(safe)
	content_root.position = MenuLayout.origin_for(safe)
	if boost_preview_active:
		preview_car.animate(0, false, true, delta)
		var rotation := Vector3.ZERO
		if "air_spin" in preview_car.equipped_effects and not race.motion_reduced:
			effect_preview_time += delta
			rotation = Vector3.FORWARD * TAU * smoothstep(0, .8, minf(effect_preview_time, .8))
		preview_car.set_presentation_rotation(rotation)
		request_preview_render()
	elif preview_car.boost_fx != null and preview_car.boost_fx.heat > 0:
		preview_car.set_presentation_rotation(Vector3.ZERO)
		preview_car.animate(0, false, false, delta)
		request_preview_render()


func request_close() -> void:
	if color_sheet.visible:
		close_sheet(color_sheet)
		return
	if discard_dialog.visible:
		close_sheet(discard_dialog)
		return
	if draft_customization != saved_customization:
		show_sheet(discard_dialog, discard_keep)
	else:
		discard()


func discard() -> void:
	race.tuning_shop = null
	queue_free()
	race.shell.sync_back()


func apply_changes() -> void:
	var error: Error = race.customization.save(vehicle_index, draft_customization)
	if error != OK:
		save_status_label.text = "COULD NOT SAVE. PLEASE TRY AGAIN."
		save_status_label.add_theme_color_override("font_color", TuningTheme.CORAL)
		return
	saved_customization = draft_customization.duplicate(true)
	is_comparing = false
	race.apply_cosmetics()
	refresh_customization()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(content_root):
		call_deferred("fit_translated_text")


func fit_translated_text() -> void:
	# 원문을 보존하고 실제 번역 표시는 Control에 맡긴다. 언어를 바꿔도 원문 키를 잃지 않는다.
	for control in content_root.find_children("*", "Control", true, false):
		if not control.has_meta("tuning_font_size"):
			continue
		var font_size: int = control.get_meta("tuning_font_size")
		var minimum := mini(font_size, 24)
		var available: float = control.size.x - (20 if control is Button else 4)
		if control is Button and control.icon != null:
			available -= 68
		var font: Font = control.get_theme_font("font")
		var translated: String = control.tr(control.text)
		while (
			font_size > minimum
			and font.get_string_size(translated, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available
		):
			font_size -= 1
		control.add_theme_font_size_override("font_size", font_size)


func build_sheets() -> void:
	var Sheet = preload("res://scripts/ui/tuning/tuning_sheet.gd")
	discard_dialog = Sheet.new()
	content_root.add_child(discard_dialog)
	var panel := preload("res://scripts/ui/tuning/tuning_panel.gd").new()
	panel.position = Vector2(260, 206)
	panel.size = Vector2(760, 308)
	panel.fill = TuningTheme.PAPER
	discard_dialog.add_child(panel)
	add_label("Leave Coast Customs?", Rect2(292, 226, 696, 56), 34, TuningTheme.INK, discard_dialog)
	add_label("Your changes have not been applied.", Rect2(292, 296, 696, 58), 28, TuningTheme.MUTED, discard_dialog)
	discard_keep = add_button(
		"KEEP EDITING", Rect2(292, 398, 330, 80), func(): close_sheet(discard_dialog), 26, discard_dialog
	)
	var confirm := add_button(
		"DISCARD CHANGES", Rect2(658, 398, 330, 80), func(): discard_dialog.confirmed.emit(), 26, discard_dialog
	)
	TuningTheme.apply_accent_style(confirm, TuningTheme.CORAL)
	discard_dialog.confirmed.connect(discard)
	color_sheet = Sheet.new()
	content_root.add_child(color_sheet)
	var color_panel := preload("res://scripts/ui/tuning/tuning_panel.gd").new()
	color_panel.position = Vector2(320, 42)
	color_panel.size = Vector2(640, 636)
	color_panel.fill = TuningTheme.PAPER
	color_sheet.add_child(color_panel)
	add_label("CUSTOM COLOR", Rect2(350, 60, 580, 60), 34, TuningTheme.INK, color_sheet)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(350, 138)
	scroll.size = Vector2(580, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_sheet.add_child(scroll)
	custom_picker = ColorPicker.new()
	custom_picker.custom_minimum_size = Vector2(554, 400)
	custom_picker.add_theme_constant_override("h_width", 80)
	custom_picker.edit_alpha = false
	custom_picker.presets_visible = false
	custom_picker.color_modes_visible = false
	custom_picker.sliders_visible = false
	custom_picker.hex_visible = false
	custom_picker.sampler_visible = false
	scroll.add_child(custom_picker)
	for slider in custom_picker.find_children("*", "Slider", true, false):
		slider.custom_minimum_size.y = 80
	for button in custom_picker.find_children("*", "BaseButton", true, false):
		button.custom_minimum_size.y = 80
	custom_picker.color_changed.connect(
		func(color: Color): set_customization_value(custom_color_key, color.to_html(false))
	)
	color_done = add_button("DONE", Rect2(350, 580, 580, 80), func(): close_sheet(color_sheet), 30, color_sheet)
	TuningTheme.apply_accent_style(color_done, TuningTheme.YELLOW)


func open_custom_color(key: String) -> void:
	custom_color_key = key
	custom_picker.color = Color(draft_customization[key])
	show_sheet(color_sheet, color_done)


func show_sheet(sheet: Control, first: Control) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	modal_focus_modes.clear()
	for control in content_root.find_children("*", "Control", true, false):
		if sheet.is_ancestor_of(control) or control == sheet:
			continue
		if control.focus_mode != Control.FOCUS_NONE:
			modal_focus_modes[control] = control.focus_mode
			control.focus_mode = Control.FOCUS_NONE
	sheet.show()
	first.grab_focus()


func close_sheet(sheet: Control) -> void:
	sheet.hide()
	for control in modal_focus_modes:
		if is_instance_valid(control):
			control.focus_mode = modal_focus_modes[control]
	modal_focus_modes.clear()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func focus_back(back: Button) -> void:
	if back.focus_mode != Control.FOCUS_NONE and not color_sheet.visible and not discard_dialog.visible:
		back.grab_focus()
