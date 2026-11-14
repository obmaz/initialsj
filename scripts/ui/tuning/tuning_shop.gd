extends CanvasLayer
const VehicleFactory = preload("res://scripts/vehicles/vehicle_factory.gd")
const VehicleCatalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const CustomizationStore = preload("res://scripts/vehicles/customization_store.gd")
const Effects = preload("res://scripts/vehicles/effect_items.gd")
const Customization = preload("res://scripts/vehicles/vehicle_customization.gd")
const MenuLayout = preload("res://scripts/ui/menu_layout.gd")
const TuningTheme = preload("res://scripts/ui/tuning/tuning_theme.gd")
const Art = preload("res://scripts/ui/rev3_art.gd")
var art := Art.new()
var skin: Control
var art_buttons: Dictionary = {}
var responsive_controls: Dictionary = {}
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
var color_before_edit := ""
var color_previous: ColorRect
var color_current: ColorRect
var color_channels: Array[HSlider] = []
var channel_labels: Array[Label] = []
var color_syncing := false
var discard_keep: Button
var color_done: Button
var previous_focus: Control
var modal_focus_modes: Dictionary = {}


func _ready() -> void:
	layer = 30
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color("355d77")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	content_root = Control.new()
	content_root.size = DESIGN_SIZE
	content_root.theme = TuningTheme.create_theme()
	add_child(content_root)
	skin = Control.new()
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.draw.connect(draw_skin)
	content_root.add_child(skin)
	create_preview()
	build_layout()
	options_scroll = ScrollContainer.new()
	options_scroll.position = Vector2(54, 230)
	options_scroll.size = Vector2(404, 367)
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
	shadow.position = Vector2(540, 480)
	shadow.size = Vector2(650, 52)
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
	preview_display.position = Vector2(492, 236)
	preview_display.texture = preview_viewport.get_texture()
	preview_display.size = Vector2(748, 282)
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_display.gui_input.connect(drag_preview)
	content_root.add_child(preview_display)


func build_layout() -> void:
	var back := skin_button("‹", "back", request_close, 38)
	back.name = "Back"
	call_deferred("focus_back", back)
	var title := add_label("COAST CUSTOMS", Rect2(330, 16, 560, 78), 40, Art.WHITE)
	title.name = "Title"
	title.set_meta("base_position", title.position)
	responsive_controls[title] = "header"
	var name_label := add_label(str(VehicleCatalog.spec(vehicle_index).name), Rect2(918, 25, 182, 56), 24, Art.GOLD)
	name_label.set_meta("base_position", name_label.position)
	responsive_controls[name_label] = "header_right"
	# 저장된 탭 번호와 원화 순서는 별개다. ID로 연결해 셰이딩·이펙트가 뒤바뀌지 않게 한다.
	for i in range(6):
		var id: String = ["tab_paint", "tab_livery", "tab_wheels", "tab_wing", "tab_effects", "tab_shading"][i]
		var tab := skin_button(
			["PAINT", "LIVERY", "WHEELS", "REAR WING", "EFFECTS", "SHADING"][i],
			id,
			func():
				selected_tab = i
				rebuild_options(),
			23
		)
		tab.toggle_mode = true
		tab.add_theme_constant_override("outline_size", 0)
		tab_buttons.append(tab)
		var icon := TextureRect.new()
		var icon_screen := "car_select" if id == "tab_effects" else "tuning_shop"
		var icon_id := "performance_2_icon" if id == "tab_effects" else id + "_icon"
		var entry: Dictionary = art.index(icon_screen)[icon_id].layer
		var asset: Dictionary = Art.data().assets[entry.asset]
		var image := AtlasTexture.new()
		image.atlas = art.texture(asset.path)
		var region: Array = asset.region
		image.region = Rect2(
			region[0], region[1], 75 if id == "tab_effects" else (80 if id == "tab_shading" else region[2]), region[3]
		)
		icon.texture = image
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(66, 10)
		icon.size = Vector2(68, 45)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(icon)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = tab.get_theme_stylebox(state).duplicate()
			style.content_margin_top = 50
			tab.add_theme_stylebox_override(state, style)
	var left := skin_button("‹", "camera_left", func(): rotate_preview(-.45), 34)
	var right := skin_button("›", "camera_right", func(): rotate_preview(.45), 34)
	left.tooltip_text = "ROTATE LEFT"
	right.tooltip_text = "ROTATE RIGHT"
	boost_button = add_button("BOOST", Rect2(970, 514, 180, 80), toggle_boost, 23)
	boost_button.toggle_mode = true
	compare_button = add_button("COMPARE", Rect2(778, 514, 176, 80), toggle_compare, 23)
	compare_button.toggle_mode = true
	responsive_controls[compare_button] = "preview"
	responsive_controls[boost_button] = "preview"
	skin_button("CANCEL", "cancel", request_close, 27)
	skin_button("RESET", "reset", reset_draft, 27)
	apply_button = skin_button("APPLY  »", "apply", apply_changes, 30)
	save_status_label = add_label("", Rect2(590, 223, 550, 34), 20, Art.GOLD)
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func skin_button(text: String, id: String, action: Callable, size_px: int) -> Button:
	var button := add_button(text, art.source_rect("tuning_shop", id), action, size_px)
	var style := TuningTheme.create_panel_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 18)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	var selected := TuningTheme.create_panel_style(Color.TRANSPARENT, Art.GOLD, 3, 18)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("disabled", style)
	art_buttons[button] = id
	return button


func rotate_preview(angle: float) -> void:
	preview_car.rotation.y += angle
	request_preview_render()


func art_area() -> Rect2:
	var safe := MenuLayout.safe_rect(get_viewport().get_visible_rect().size)
	var scale_factor := MenuLayout.scale_for(safe)
	return Rect2((safe.position - content_root.position) / scale_factor, safe.size / scale_factor)


func draw_skin() -> void:
	var bounds := art_area()
	art.background(
		skin,
		"tuning_shop",
		Rect2(-content_root.position / content_root.scale, get_viewport().get_visible_rect().size / content_root.scale)
	)
	for id in ["header", "wrench"]:
		art.draw_part(skin, "tuning_shop", id, art.rect("tuning_shop", id, bounds))
	Art.draw_panel(skin, art.rect("tuning_shop", "options", bounds))
	Art.draw_panel(skin, Rect2(580, 219, 570, 42), false, 12)
	for button in art_buttons:
		var id: String = art_buttons[button]
		Art.draw_panel(
			skin,
			art.rect("tuning_shop", id, bounds),
			id == "apply",
			36 if id in ["camera_left", "camera_right"] else 20
		)


func _exit_tree() -> void:
	art.release()


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
	add_label(title, Rect2(5, y, 300, 68), 24, TuningTheme.INK, options_panel)
	var picker := add_button("+", Rect2(310, y, 80, 80), func(): open_custom_color(key), 32, options_panel)
	picker.set_meta("color_key", key)
	picker.tooltip_text = "CUSTOM COLOR"
	TuningTheme.apply_swatch_style(picker, Color(draft_customization[key]))
	for i in range(colors.size()):
		var color := Color(colors[i])
		var node := add_button(
			"",
			Rect2((i % 4) * 99, y + 68 + (i / 4) * 93, 90, 86),
			func(): set_customization_value(key, colors[i]),
			14,
			options_panel
		)
		node.toggle_mode = true
		node.tooltip_text = "#" + str(colors[i]).to_upper()
		node.set_meta("selection_key", key)
		node.set_meta("selection_value", colors[i])
		TuningTheme.apply_swatch_style(node, color)
		add_selection_badge(node)


func rebuild_options() -> void:
	for i in range(tab_buttons.size()):
		tab_buttons[i].set_pressed_no_signal(i == selected_tab)
	for child in options_panel.get_children():
		child.free()
	options_scroll.scroll_vertical = 0
	options_panel.custom_minimum_size = Vector2(398, 872 if selected_tab == 0 else 364)
	if selected_tab == 0:
		build_color_options("paint", "BODY COLOR", 0, PAINT_COLORS.slice(0, 8))
		build_color_options("secondary", "ACCENT COLOR", 410, PAINT_COLORS)
		for i in range(3):
			add_choice_button(["GLOSS", "MATTE", "METAL"][i], Rect2(i * 132, 264, 128, 90), "finish", i, 22)
		var plate := add_button("", Rect2(0, 780, 398, 80), cycle_plate, 22, options_panel)
		plate.name = "PlateChoice"
	elif selected_tab == 1:
		for i in range(4):
			var choice := add_choice_button(LIVERY_LABELS[i], Rect2(0, i * 92, 398, 86), "livery", i, 22)
			if i > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = load(Customization.ATLAS)
				atlas.region = Rect2(
					Vector2(
						mini(vehicle_index, 3) * atlas.atlas.get_width() / 4.0, (i - 1) * atlas.atlas.get_height() / 3.0
					),
					Vector2(atlas.atlas.get_width() / 4.0, atlas.atlas.get_height() / 3.0)
				)
				choice.icon = atlas
				choice.expand_icon = true
				choice.add_theme_constant_override("icon_max_width", 100)
	elif selected_tab == 2:
		for i in range(3):
			var choice := add_choice_button(WHEEL_LABELS[i], Rect2(0, i * 94, 398, 90), "wheel", i, 22)
			choice.icon = art.icon("tuning_wheels", "wheel_thumb_%d" % i)
			choice.expand_icon = true
			choice.add_theme_constant_override("icon_max_width", 78)
		for i in range(5):
			var color: String = ["b7bec4", "dfb65a", "252c35", "edf1ef", "20cbd0"][i]
			var swatch := add_button(
				"", Rect2(i * 80, 284, 76, 80), func(): set_customization_value("rim", color), 22, options_panel
			)
			swatch.toggle_mode = true
			swatch.set_meta("selection_key", "rim")
			swatch.set_meta("selection_value", color)
			TuningTheme.apply_swatch_style(swatch, Color(color))
	elif selected_tab == 3:
		for i in range(4):
			var choice := add_choice_button(WING_LABELS[i], Rect2(0, i * 92, 398, 86), "wing", i, 22)
			choice.icon = art.icon("tuning_rear_wing", "wing_%d_icon" % i, 156)
			choice.expand_icon = true
			choice.add_theme_constant_override("icon_max_width", 90)
	elif selected_tab == 4:
		var slots := add_label("", Rect2(4, 0, 390, 45), 23, Art.GOLD, options_panel)
		slots.name = "EffectSlots"
		for i in range(Effects.IDS.size()):
			var id: String = Effects.IDS[i]
			var button := add_button(
				Effects.LABELS[i], Rect2(0, 48 + i * 105, 398, 99), func(): toggle_effect(id), 23, options_panel
			)
			button.toggle_mode = true
			button.set_meta("effect_id", id)
			add_selection_badge(button)
			button.tooltip_text = (
				Effects.HELP[i] if Effects.supported(id, vehicle_index) else "Not available for this vehicle."
			)
			button.icon = art.icon("tuning_effects", "effect_%d_icon" % i, 140)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 78)
	else:
		for i in range(2):
			var choice := add_choice_button(["NORMAL", "TOON"][i], Rect2(i * 202, 4, 196, 180), "shading", i, 24)
			var sphere := TextureRect.new()
			sphere.texture = art.icon("tuning_shading", "material_%d" % i)
			sphere.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sphere.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sphere.position = Vector2(23, 10)
			sphere.size = Vector2(150, 120)
			sphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
			choice.add_child(sphere)
			for state in ["normal", "hover", "pressed", "disabled"]:
				var style := choice.get_theme_stylebox(state).duplicate()
				style.content_margin_top = 132
				choice.add_theme_stylebox_override(state, style)
		var label := add_label("", Rect2(4, 193, 390, 40), 23, Art.WHITE, options_panel)
		label.name = "ToonValue"
		var slider := HSlider.new()
		slider.name = "ToonStrength"
		for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(icon, preload("res://assets/ui/controls/slider_knob.svg"))
		slider.position = Vector2(8, 235)
		slider.size = Vector2(382, 80)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value_changed.connect(func(value: float): set_customization_value("toon_strength", int(value)))
		options_panel.add_child(slider)
		var help := add_label(
			"Higher strength gives flatter shadows and stronger outlines.",
			Rect2(4, 315, 390, 48),
			19,
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
	add_selection_badge(node)
	return node


func set_customization_value(key: String, value: Variant) -> void:
	draft_customization[key] = value
	is_comparing = false
	refresh_customization()
	if is_instance_valid(color_sheet) and color_sheet.visible:
		sync_color_controls()


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
			child.add_theme_color_override("font_color", Color("233f52") if color.get_luminance() > .4 else Color.WHITE)
	for child in options_panel.get_children():
		if child is Button and child.has_node("SelectedBadge"):
			child.get_node("SelectedBadge").visible = child.button_pressed
	var plate := options_panel.get_node_or_null("PlateChoice") as Button
	if plate != null:
		plate.text = (
			tr("PLATE: %s")
			% race.passport.PLATES[CustomizationStore.plate_index(draft_customization, vehicle_index, race.passport)]
		)
	refresh_effect_slot_label()
	var toon_slider := options_panel.get_node_or_null("ToonStrength") as HSlider
	if toon_slider != null:
		toon_slider.editable = draft_customization.shading == 1
		toon_slider.set_value_no_signal(draft_customization.toon_strength)
		options_panel.get_node("ToonValue").text = tr("TOON STRENGTH %d%%") % draft_customization.toon_strength

	var preview_customization: Dictionary = saved_customization if is_comparing else draft_customization
	CustomizationStore.apply_selection(preview_car, preview_customization, vehicle_index, race.passport)
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
		"font_color", Art.GOLD if draft_customization != saved_customization and not is_comparing else Art.WHITE
	)
	fit_translated_text()
	request_preview_render()


func cycle_plate() -> void:
	var choices: Array = race.passport.unlocked_plates()
	if choices.size() <= 1:
		save_status_label.text = "FINISH A TOUR TO UNLOCK PLATES"
		save_status_label.add_theme_color_override("font_color", Art.GOLD)
		return
	var current := CustomizationStore.plate_index(draft_customization, vehicle_index, race.passport)
	set_customization_value("plate", choices[(choices.find(current) + 1) % choices.size()])


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
	for button in art_buttons:
		var bounds := art.rect("tuning_shop", art_buttons[button], art_area())
		button.position = bounds.position
		button.size = bounds.size
	for control in responsive_controls:
		if responsive_controls[control] == "preview":
			control.position.y = 514
		else:
			var base: Vector2 = control.get_meta("base_position")
			control.position = (
				base
				+ Vector2(
					(
						art_area().end.x - 1280
						if responsive_controls[control] == "header_right"
						else art_area().position.x
					),
					art_area().position.y
				)
			)
	skin.queue_redraw()
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
		cancel_custom_color()
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


func refresh_effect_slot_label() -> void:
	if not is_instance_valid(options_panel):
		return
	var count_label := options_panel.get_node_or_null("EffectSlots") as Label
	if count_label != null:
		count_label.text = (
			tr("EFFECT SLOTS %d / %d") % [draft_customization.effects.size(), Effects.slots(vehicle_index)]
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(content_root):
		call_deferred("refresh_customization")
		call_deferred("fit_translated_text")


func fit_translated_text() -> void:
	# 원문을 보존하고 실제 번역 표시는 Control에 맡긴다. 언어를 바꿔도 원문 키를 잃지 않는다.
	for control in content_root.find_children("*", "Control", true, false):
		if not control.has_meta("tuning_font_size"):
			continue
		var font_size: int = control.get_meta("tuning_font_size")
		var minimum := mini(font_size, 20)
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
	const TuningSheet = preload("res://scripts/ui/tuning/tuning_sheet.gd")
	discard_dialog = TuningSheet.new()
	content_root.add_child(discard_dialog)
	var panel := preload("res://scripts/ui/tuning/tuning_panel.gd").new()
	panel.position = Vector2(370, 213)
	panel.size = Vector2(538, 354)
	panel.fill = TuningTheme.PAPER
	discard_dialog.add_child(panel)
	add_label("Leave Coast Customs?", Rect2(400, 235, 478, 65), 34, TuningTheme.INK, discard_dialog)
	add_label("Your changes have not been applied.", Rect2(400, 320, 478, 70), 28, TuningTheme.MUTED, discard_dialog)
	discard_keep = add_button(
		"KEEP EDITING", Rect2(394, 428, 245, 121), func(): close_sheet(discard_dialog), 26, discard_dialog
	)
	var confirm := add_button(
		"DISCARD CHANGES", Rect2(642, 428, 244, 121), func(): discard_dialog.confirmed.emit(), 26, discard_dialog
	)
	TuningTheme.apply_accent_style(confirm, TuningTheme.CORAL)
	discard_dialog.confirmed.connect(discard)
	color_sheet = TuningSheet.new()
	content_root.add_child(color_sheet)
	var color_panel := preload("res://scripts/ui/tuning/tuning_panel.gd").new()
	color_panel.position = Vector2(279, 188)
	color_panel.size = Vector2(722, 484)
	color_panel.fill = TuningTheme.PAPER
	color_sheet.add_child(color_panel)
	add_label("CUSTOM COLOR", Rect2(310, 203, 660, 60), 34, TuningTheme.INK, color_sheet)
	custom_picker = ColorPicker.new()
	custom_picker.position = Vector2(300, 263)
	custom_picker.custom_minimum_size = Vector2(277, 285)
	custom_picker.size = Vector2(277, 285)
	custom_picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	custom_picker.edit_alpha = false
	custom_picker.presets_visible = false
	custom_picker.color_modes_visible = false
	custom_picker.sliders_visible = false
	custom_picker.hex_visible = false
	custom_picker.sampler_visible = false
	color_sheet.add_child(custom_picker)
	custom_picker.color_changed.connect(
		func(color: Color):
			if not color_syncing:
				set_customization_value(custom_color_key, color.to_html(false))
	)
	for i in range(2):
		add_label("PREVIOUS" if i == 0 else "NEW", Rect2(606 + i * 186, 242, 174, 28), 20, Art.WHITE, color_sheet)
		var sample := ColorRect.new()
		sample.position = Vector2(606 + i * 186, 273)
		sample.size = Vector2(174, 62)
		sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_sheet.add_child(sample)
		if i == 0:
			color_previous = sample
		else:
			color_current = sample
	for i in range(3):
		add_label(
			["R", "G", "B"][i],
			Rect2(602, 344 + i * 72, 32, 72),
			23,
			[Color("ff8b79"), Color("a1e0b3"), Color("a1c9f0")][i],
			color_sheet
		)
		var slider := HSlider.new()
		slider.position = Vector2(638, 344 + i * 72)
		slider.size = Vector2(276, 72)
		slider.min_value = 0
		slider.max_value = 255
		slider.step = 1
		for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(icon, preload("res://assets/ui/controls/slider_knob.svg"))
		slider.value_changed.connect(func(value: float): set_color_channel(i, value))
		color_sheet.add_child(slider)
		color_channels.append(slider)
		var number := add_label("", Rect2(921, 344 + i * 72, 54, 72), 22, Art.WHITE, color_sheet)
		channel_labels.append(number)
	color_done = add_button("DONE", Rect2(625, 560, 349, 89), func(): close_sheet(color_sheet), 30, color_sheet)
	TuningTheme.apply_accent_style(color_done, TuningTheme.CORAL)
	add_button("CANCEL", Rect2(305, 560, 308, 89), cancel_custom_color, 27, color_sheet)


func add_selection_badge(button: Button) -> void:
	var badge := TextureRect.new()
	badge.name = "SelectedBadge"
	badge.texture = art.icon("track_select", "selected_course")
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.position = Vector2(button.size.x - 28, 5)
	badge.size = Vector2(23, 23)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	button.add_child(badge)


func set_color_channel(channel: int, value: float) -> void:
	if color_syncing:
		return
	var color := Color(draft_customization[custom_color_key])
	color[channel] = value / 255.0
	set_customization_value(custom_color_key, color.to_html(false))


func sync_color_controls() -> void:
	color_syncing = true
	var color := Color(draft_customization[custom_color_key])
	custom_picker.color = color
	color_current.color = color
	for i in range(3):
		color_channels[i].set_value_no_signal(roundi(color[i] * 255))
		channel_labels[i].text = str(roundi(color[i] * 255))
	color_syncing = false


func cancel_custom_color() -> void:
	set_customization_value(custom_color_key, color_before_edit)
	close_sheet(color_sheet)


func open_custom_color(key: String) -> void:
	custom_color_key = key
	color_before_edit = draft_customization[key]
	color_previous.color = Color(color_before_edit)
	sync_color_controls()
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
	if (
		race.gamepad_active
		and back.focus_mode != Control.FOCUS_NONE
		and not color_sheet.visible
		and not discard_dialog.visible
	):
		back.grab_focus()
