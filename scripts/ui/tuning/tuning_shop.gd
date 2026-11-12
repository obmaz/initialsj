extends CanvasLayer
const VehicleFactory = preload("res://scripts/vehicles/vehicle_factory.gd")
const VehicleCatalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const CustomizationStore = preload("res://scripts/vehicles/customization_store.gd")
const Customization = preload("res://scripts/vehicles/vehicle_customization.gd")
const TuningTheme = preload("res://scripts/ui/tuning/tuning_theme.gd")
const BACKGROUND_PATH := "res://assets/ui/backgrounds/tuning_bay.png"
const DESIGN_SIZE := Vector2(1280, 720)
const PAINT_COLORS := [
	"edf1ef", "20cbd0", "fb686e", "ffdc48", "173454", "b7bec4", "777e89", "509bed", "aa80d3", "252c35"
]
const LIVERY_LABELS := ["ORIGINAL", "HERITAGE STRIPES", "COAST WAVES", "CIRCUIT GRAPHIC"]
const WHEEL_LABELS := ["ORIGINAL WHEELS", "FORGED FIVE SPOKE", "SPLIT SPOKE"]
const WING_LABELS := ["ORIGINAL AERO", "LOW DUCKTAIL", "GT REAR WING", "NO WING"]
var race: Node3D
var content_root: Control
var options_panel: Control
var preview_viewport: SubViewport
var preview_camera: Camera3D
var preview_display: TextureRect
var preview_car: Node3D
var selection_summary: Label
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
var vehicle_index := 0
var mouse_drag_active := false
var active_touch_index := -1
var discard_dialog: ConfirmationDialog


func _ready() -> void:
	layer = 30
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
	options_panel = Control.new()
	options_panel.position = Vector2(38, 182)
	options_panel.size = Vector2(274, 412)
	content_root.add_child(options_panel)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Leave Coast Customs?"
	discard_dialog.dialog_text = "Your changes have not been applied."
	discard_dialog.ok_button_text = "DISCARD CHANGES"
	discard_dialog.cancel_button_text = "KEEP EDITING"
	discard_dialog.confirmed.connect(discard)
	content_root.add_child(discard_dialog)
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
	shadow.position = Vector2(555, 470)
	shadow.size = Vector2(610, 90)
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
	environment.ambient_light_energy = .85
	world.environment = environment
	preview_viewport.add_child(world)
	for pose in [Vector3(-40, -35, 0), Vector3(-15, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = pose
		light.light_energy = 1.15 if pose.y < 0 else .55
		preview_viewport.add_child(light)
	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(-3.7, 1.7, -4.5)
	preview_camera.fov = 27
	preview_viewport.add_child(preview_camera)
	preview_camera.look_at(Vector3(0, .65, 0))
	preview_car = VehicleFactory.create(vehicle_index)
	preview_viewport.add_child(preview_car)
	race.passport.apply_car(preview_car, vehicle_index)
	preview_car.reduced_motion = race.motion_reduced
	preview_car.effects_quality = race.player.effects_quality
	preview_display = TextureRect.new()
	preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_display.position = Vector2(345, 154)
	preview_display.texture = preview_viewport.get_texture()
	preview_display.size = Vector2(915, 414)
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_display.gui_input.connect(drag_preview)
	content_root.add_child(preview_display)


func build_layout() -> void:
	add_panel(Rect2(0, 0, 1280, 82), Color("ffffffed"))
	var back := add_button("<", Rect2(20, 17, 68, 50), request_close, 30)
	TuningTheme.apply_accent_style(back, TuningTheme.CORAL)
	back.call_deferred("grab_focus")
	add_label("COAST CUSTOMS", Rect2(110, 11, 700, 42), 34)
	add_label("MAKE IT YOURS", Rect2(113, 51, 440, 23), 14, TuningTheme.MUTED)
	add_panel(Rect2(1025, 17, 235, 50), TuningTheme.YELLOW)
	var name_label := add_label(str(VehicleCatalog.spec(vehicle_index).name), Rect2(1035, 19, 215, 46), 25)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(4):
		var tab_button := add_button(
			["PAINT", "LIVERY", "WHEELS", "REAR WING"][i],
			Rect2(20 + i * 310, 96, 300, 52),
			func():
				selected_tab = i
				rebuild_options(),
			21
		)
		tab_button.toggle_mode = true
		tab_buttons.append(tab_button)
	add_panel(Rect2(20, 166, 310, 450), Color("ffffffed"))
	add_panel(Rect2(350, 164, 910, 32), Color("ffffffd9"))
	selection_summary = add_label("", Rect2(360, 166, 885, 28), 14, TuningTheme.INK)
	selection_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_panel(Rect2(350, 568, 910, 48), Color("fffffff0"))
	for i in range(3):
		add_button(["FRONT", "SIDE", "REAR"][i], Rect2(360 + i * 105, 570, 98, 44), func(): set_view(i), 15)
	add_label("DRAG TO ROTATE", Rect2(688, 580, 290, 27), 16, TuningTheme.MUTED)
	boost_button = add_button("BOOST PREVIEW", Rect2(1040, 570, 210, 44), toggle_boost, 16)
	boost_button.toggle_mode = true
	add_panel(Rect2(0, 634, 1280, 86), Color("fffffff5"))
	add_button("RESET", Rect2(20, 651, 120, 50), reset_draft, 17)
	compare_button = add_button("COMPARE", Rect2(152, 651, 150, 50), toggle_compare, 17)
	compare_button.toggle_mode = true
	add_button("CANCEL", Rect2(314, 651, 120, 50), request_close, 17)
	save_status_label = add_label("", Rect2(460, 653, 535, 46), 17)
	save_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_button = add_button("APPLY", Rect2(1020, 649, 240, 54), apply_changes, 25)
	TuningTheme.apply_accent_style(apply_button, TuningTheme.YELLOW)


func add_panel(rect: Rect2, color: Color) -> void:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", TuningTheme.create_panel_style(color, Color("ffffff55"), 1, 8))
	content_root.add_child(node)


func add_label(
	text: String, rect: Rect2, size_px: int, color: Color = TuningTheme.INK, parent: Control = null
) -> Label:
	var node := Label.new()
	node.text = text
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
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size_px)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.pressed.connect(action)
	(parent if parent != null else content_root).add_child(node)
	return node


func build_color_options(key: String, title: String, y: float, colors: Array) -> void:
	add_label(title, Rect2(0, y, 183, 26), 18, TuningTheme.INK, options_panel)
	var picker := ColorPickerButton.new()
	picker.position = Vector2(194, y)
	picker.size = Vector2(80, 28)
	picker.text = "CUSTOM"
	picker.add_theme_font_size_override("font_size", 12)
	picker.edit_alpha = false
	picker.color = Color(draft_customization[key])
	picker.set_meta("color_key", key)
	picker.color_changed.connect(func(color: Color): set_customization_value(key, color.to_html(false)))
	options_panel.add_child(picker)
	var mark := Label.new()
	mark.name = "CustomMark"
	mark.text = "+"
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(mark)
	picker.tooltip_text = "CUSTOM COLOR"
	picker.get_picker().presets_visible = false
	picker.get_picker().color_modes_visible = false
	for i in range(colors.size()):
		var color := Color(colors[i])
		var node := add_button(
			"",
			Rect2((i % 5) * 55, y + 35 + (i / 5) * 50, 44, 44),
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
	if selected_tab == 0:
		build_color_options("paint", "BODY COLOR", 0, PAINT_COLORS)
		build_color_options("secondary", "ACCENT COLOR", 153, PAINT_COLORS)
		add_label("FINISH", Rect2(0, 305, 274, 25), 18, TuningTheme.INK, options_panel)
		for i in range(3):
			add_choice_button(["GLOSS", "MATTE", "METALLIC"][i], Rect2(i * 93, 341, 88, 48), "finish", i, 14)
	elif selected_tab == 1:
		var notes := ["Clean factory finish", "Classic racing lines", "A little ocean motion", "Race-day graphics"]
		for i in range(4):
			var choice := add_choice_button(
				LIVERY_LABELS[i] + "\n" + notes[i], Rect2(0, i * 91, 274, 80), "livery", i, 16
			)
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
			add_choice_button(WHEEL_LABELS[i], Rect2(0, i * 80, 274, 68), "wheel", i, 17)
		build_color_options("rim", "RIM COLOR", 259, ["b7bec4", "dfb65a", "252c35", "edf1ef", "20cbd0"])
	else:
		var notes := ["The original silhouette", "Low and clean", "A proper racing profile", "Keep it simple"]
		for i in range(4):
			add_choice_button(WING_LABELS[i] + "\n" + notes[i], Rect2(0, i * 91, 274, 80), "wing", i, 17)
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
		elif child is ColorPickerButton:
			# 색상 선택 창을 다시 열어도 팔레트에서 고른 현재 색을 보여준다.
			var color := Color(draft_customization[child.get_meta("color_key")])
			if not child.color.is_equal_approx(color):
				child.color = color
			var ink := TuningTheme.INK if color.get_luminance() > .4 else Color.WHITE
			child.get_node("CustomMark").add_theme_color_override("font_color", ink)
			for state in ["font_color", "font_hover_color", "font_pressed_color"]:
				child.add_theme_color_override(state, ink)
	var data: Dictionary = saved_customization if is_comparing else draft_customization
	Customization.apply(preview_car, data, vehicle_index)
	selection_summary.text = (
		"%s  /  %s  /  %s  /  %s"
		% [
			["GLOSS", "MATTE", "METALLIC"][data.finish],
			LIVERY_LABELS[data.livery],
			WHEEL_LABELS[data.wheel],
			WING_LABELS[data.wing]
		]
	)
	compare_button.set_pressed_no_signal(is_comparing)
	apply_button.disabled = draft_customization == saved_customization
	save_status_label.text = (
		"SHOWING SAVED LOOK"
		if is_comparing
		else ("CHANGES NOT SAVED" if draft_customization != saved_customization else "YOUR LOOK IS APPLIED")
	)
	save_status_label.add_theme_color_override(
		"font_color",
		TuningTheme.CORAL if draft_customization != saved_customization and not is_comparing else TuningTheme.MUTED
	)
	request_preview_render()


func reset_draft() -> void:
	draft_customization = CustomizationStore.defaults(vehicle_index)
	is_comparing = false
	rebuild_options()


func toggle_compare() -> void:
	is_comparing = not is_comparing
	refresh_customization()


func toggle_boost() -> void:
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
	var size := get_viewport().get_visible_rect().size
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	content_root.scale = Vector2.ONE * factor
	content_root.position = (size - DESIGN_SIZE * factor) * .5
	if boost_preview_active:
		preview_car.animate(0, false, true, delta)
		request_preview_render()
	elif preview_car.boost_fx != null and preview_car.boost_fx.heat > 0:
		preview_car.animate(0, false, false, delta)
		request_preview_render()


func request_close() -> void:
	for child in options_panel.get_children():
		if child is ColorPickerButton and child.get_popup().visible:
			child.get_popup().hide()
			return
	if discard_dialog.visible:
		discard_dialog.hide()
		return
	if draft_customization != saved_customization:
		discard_dialog.popup_centered(Vector2i(480, 220))
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
