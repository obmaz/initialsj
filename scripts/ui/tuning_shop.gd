extends CanvasLayer
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const Style = preload("res://scripts/ui/tuning_style.gd")
const BACKGROUND := "res://assets/ui/tuning-bay.png"
const DESIGN := Vector2(1280, 720)
const PALETTE := ["edf1ef", "20cbd0", "fb686e", "ffdc48", "173454", "b7bec4", "777e89", "509bed", "aa80d3", "252c35"]
const LIVERIES := ["ORIGINAL", "HERITAGE STRIPES", "COAST WAVES", "CIRCUIT GRAPHIC"]
const WHEELS := ["ORIGINAL WHEELS", "FORGED FIVE SPOKE", "SPLIT SPOKE"]
const WINGS := ["ORIGINAL AERO", "LOW DUCKTAIL", "GT REAR WING", "NO WING"]
var race: Node3D
var frame: Control
var options: Control
var viewport: SubViewport
var camera: Camera3D
var preview_view: TextureRect
var car: Node3D
var summary: Label
var status: Label
var apply_button: Button
var compare_button: Button
var boost_button: Button
var draft: Dictionary = {}
var saved: Dictionary = {}
var tab := 0
var tabs: Array[Button] = []
var comparing := false
var boost_demo := false
var vehicle := 0
var dragging := false
var drag_finger := -1
var closing_dialog: ConfirmationDialog


func _ready() -> void:
	layer = 30
	var background := ColorRect.new()
	background.color = Color("e6f5fa")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	frame = Control.new()
	frame.size = DESIGN
	frame.theme = Style.theme()
	add_child(frame)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load(BACKGROUND)
	art.size = DESIGN
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	create_preview()
	build_chrome()
	options = Control.new()
	options.position = Vector2(38, 182)
	options.size = Vector2(274, 412)
	frame.add_child(options)
	closing_dialog = ConfirmationDialog.new()
	closing_dialog.title = "Leave Coast Customs?"
	closing_dialog.dialog_text = "Your changes have not been applied."
	closing_dialog.ok_button_text = "DISCARD CHANGES"
	closing_dialog.cancel_button_text = "KEEP EDITING"
	closing_dialog.confirmed.connect(discard)
	frame.add_child(closing_dialog)
	build_options()
	refresh()


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
	frame.add_child(shadow)
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 344) if race.lite_graphics else Vector2i(1080, 516)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED if race.lite_graphics else Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	frame.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.TRANSPARENT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4f3ff")
	environment.ambient_light_energy = .85
	world.environment = environment
	viewport.add_child(world)
	for pose in [Vector3(-40, -35, 0), Vector3(-15, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = pose
		light.light_energy = 1.15 if pose.y < 0 else .55
		viewport.add_child(light)
	camera = Camera3D.new()
	camera.position = Vector3(-3.7, 1.7, -4.5)
	camera.fov = 27
	viewport.add_child(camera)
	camera.look_at(Vector3(0, .65, 0))
	car = Factory.create(vehicle)
	viewport.add_child(car)
	race.passport.apply_car(car, vehicle)
	car.reduced_motion = race.motion_reduced
	car.effects_quality = race.player.effects_quality
	preview_view = TextureRect.new()
	preview_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_view.position = Vector2(345, 154)
	preview_view.texture = viewport.get_texture()
	preview_view.size = Vector2(915, 414)
	preview_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_view.gui_input.connect(drag_preview)
	frame.add_child(preview_view)


func build_chrome() -> void:
	panel(Rect2(0, 0, 1280, 82), Color("ffffffed"))
	var back := button("<", Rect2(20, 17, 68, 50), request_close, 30)
	Style.accent(back, Style.CORAL)
	back.call_deferred("grab_focus")
	label("COAST CUSTOMS", Rect2(110, 11, 700, 42), 34)
	label("MAKE IT YOURS", Rect2(113, 51, 440, 23), 14, Style.MUTED)
	panel(Rect2(1025, 17, 235, 50), Style.YELLOW)
	var name_label := label(str(Catalog.spec(vehicle).name), Rect2(1035, 19, 215, 46), 25)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in range(4):
		var tab_button := button(
			["PAINT", "LIVERY", "WHEELS", "REAR WING"][i],
			Rect2(20 + i * 310, 96, 300, 52),
			func():
				tab = i
				build_options(),
			21
		)
		tab_button.toggle_mode = true
		tabs.append(tab_button)
	panel(Rect2(20, 166, 310, 450), Color("ffffffed"))
	panel(Rect2(350, 164, 910, 32), Color("ffffffd9"))
	summary = label("", Rect2(360, 166, 885, 28), 14, Style.INK)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel(Rect2(350, 568, 910, 48), Color("fffffff0"))
	for i in range(3):
		button(["FRONT", "SIDE", "REAR"][i], Rect2(360 + i * 105, 570, 98, 44), func(): set_view(i), 15)
	label("DRAG TO ROTATE", Rect2(688, 580, 290, 27), 16, Style.MUTED)
	boost_button = button("BOOST PREVIEW", Rect2(1040, 570, 210, 44), toggle_boost, 16)
	boost_button.toggle_mode = true
	panel(Rect2(0, 634, 1280, 86), Color("fffffff5"))
	button("RESET", Rect2(20, 651, 120, 50), reset_draft, 17)
	compare_button = button("COMPARE", Rect2(152, 651, 150, 50), toggle_compare, 17)
	compare_button.toggle_mode = true
	button("CANCEL", Rect2(314, 651, 120, 50), request_close, 17)
	status = label("", Rect2(460, 653, 535, 46), 17)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_button = button("APPLY", Rect2(1020, 649, 240, 54), apply_changes, 25)
	Style.accent(apply_button, Style.YELLOW)


func panel(rect: Rect2, color: Color) -> void:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", Style.box(color, Color("ffffff55"), 1, 8))
	frame.add_child(node)


func label(text: String, rect: Rect2, size_px: int, color: Color = Style.INK, parent: Control = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else frame).add_child(node)
	return node


func button(text: String, rect: Rect2, action: Callable, size_px: int = 18, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size_px)
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.pressed.connect(action)
	(parent if parent != null else frame).add_child(node)
	return node


func color_options(key: String, title: String, y: float, colors: Array) -> void:
	label(title, Rect2(0, y, 183, 26), 18, Style.INK, options)
	var picker := ColorPickerButton.new()
	picker.position = Vector2(194, y)
	picker.size = Vector2(80, 28)
	picker.text = "CUSTOM"
	picker.add_theme_font_size_override("font_size", 12)
	picker.edit_alpha = false
	picker.color = Color(draft[key])
	picker.set_meta("color_key", key)
	picker.color_changed.connect(func(color: Color): choose(key, color.to_html(false)))
	options.add_child(picker)
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
		var node := button(
			"", Rect2((i % 5) * 55, y + 35 + (i / 5) * 50, 44, 44), func(): choose(key, colors[i]), 14, options
		)
		node.toggle_mode = true
		node.tooltip_text = "#" + str(colors[i]).to_upper()
		node.set_meta("selection_key", key)
		node.set_meta("selection_value", colors[i])
		Style.swatch(node, color)


func build_options() -> void:
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == tab)
	for child in options.get_children():
		child.free()
	if tab == 0:
		color_options("paint", "BODY COLOR", 0, PALETTE)
		color_options("secondary", "ACCENT COLOR", 153, PALETTE)
		label("FINISH", Rect2(0, 305, 274, 25), 18, Style.INK, options)
		for i in range(3):
			choice_button(["GLOSS", "MATTE", "METALLIC"][i], Rect2(i * 93, 341, 88, 48), "finish", i, 14)
	elif tab == 1:
		var notes := ["Clean factory finish", "Classic racing lines", "A little ocean motion", "Race-day graphics"]
		for i in range(4):
			var choice := choice_button(LIVERIES[i] + "\n" + notes[i], Rect2(0, i * 91, 274, 80), "livery", i, 16)
			if i > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = load(Custom.ATLAS)
				atlas.region = Rect2(
					Vector2(vehicle * atlas.atlas.get_width() / 4.0, (i - 1) * atlas.atlas.get_height() / 3.0),
					Vector2(atlas.atlas.get_width() / 4.0, atlas.atlas.get_height() / 3.0)
				)
				choice.icon = atlas
				choice.expand_icon = true
				choice.add_theme_constant_override("icon_max_width", 56)
	elif tab == 2:
		for i in range(3):
			choice_button(WHEELS[i], Rect2(0, i * 80, 274, 68), "wheel", i, 17)
		color_options("rim", "RIM COLOR", 259, ["b7bec4", "dfb65a", "252c35", "edf1ef", "20cbd0"])
	else:
		var notes := ["The original silhouette", "Low and clean", "A proper racing profile", "Keep it simple"]
		for i in range(4):
			choice_button(WINGS[i] + "\n" + notes[i], Rect2(0, i * 91, 274, 80), "wing", i, 17)
	refresh()


func choice_button(text: String, rect: Rect2, key: String, value: int, size_px: int = 18) -> Button:
	var node := button(text, rect, func(): choose(key, value), size_px, options)
	node.toggle_mode = true
	node.set_meta("selection_key", key)
	node.set_meta("selection_value", value)
	return node


func choose(key: String, value: Variant) -> void:
	draft[key] = value
	comparing = false
	refresh()


func refresh() -> void:
	draft = Store.sanitize(draft, vehicle)
	for child in options.get_children():
		if child is Button and child.has_meta("selection_key"):
			child.set_pressed_no_signal(draft[child.get_meta("selection_key")] == child.get_meta("selection_value"))
		elif child is ColorPickerButton:
			# 색상 선택 창을 다시 열어도 팔레트에서 고른 현재 색을 보여준다.
			var color := Color(draft[child.get_meta("color_key")])
			if not child.color.is_equal_approx(color):
				child.color = color
			var ink := Style.INK if color.get_luminance() > .4 else Color.WHITE
			child.get_node("CustomMark").add_theme_color_override("font_color", ink)
			for state in ["font_color", "font_hover_color", "font_pressed_color"]:
				child.add_theme_color_override(state, ink)
	var data: Dictionary = saved if comparing else draft
	Custom.apply(car, data, vehicle)
	summary.text = (
		"%s  /  %s  /  %s  /  %s"
		% [["GLOSS", "MATTE", "METALLIC"][data.finish], LIVERIES[data.livery], WHEELS[data.wheel], WINGS[data.wing]]
	)
	compare_button.set_pressed_no_signal(comparing)
	apply_button.disabled = draft == saved
	status.text = (
		"SHOWING SAVED LOOK" if comparing else ("CHANGES NOT SAVED" if draft != saved else "YOUR LOOK IS APPLIED")
	)
	status.add_theme_color_override("font_color", Style.CORAL if draft != saved and not comparing else Style.MUTED)
	redraw()


func reset_draft() -> void:
	draft = Store.defaults(vehicle)
	comparing = false
	build_options()


func toggle_compare() -> void:
	comparing = not comparing
	refresh()


func toggle_boost() -> void:
	boost_demo = not boost_demo
	boost_button.set_pressed_no_signal(boost_demo)


func set_view(index: int) -> void:
	car.rotation.y = 0
	camera.position = [Vector3(0, 1.6, -6.4), Vector3(-6.4, 1.6, 0), Vector3(0, 1.6, 6.4)][index]
	camera.look_at(Vector3(0, .65, 0))
	redraw()


func redraw() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func drag_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventScreenTouch:
		if event.pressed and drag_finger < 0:
			drag_finger = event.index
		elif not event.pressed and event.index == drag_finger:
			drag_finger = -1
	if (event is InputEventMouseMotion and dragging) or (event is InputEventScreenDrag and event.index == drag_finger):
		car.rotation.y += event.relative.x * .008
		redraw()


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - DESIGN * factor) * .5
	if boost_demo:
		car.animate(0, false, true, delta)
		redraw()
	elif car.boost_fx != null and car.boost_fx.heat > 0:
		car.animate(0, false, false, delta)
		redraw()


func request_close() -> void:
	for child in options.get_children():
		if child is ColorPickerButton and child.get_popup().visible:
			child.get_popup().hide()
			return
	if closing_dialog.visible:
		closing_dialog.hide()
		return
	if draft != saved:
		closing_dialog.popup_centered(Vector2i(480, 220))
	else:
		discard()


func discard() -> void:
	race.tuning_shop = null
	queue_free()
	race.shell.sync_back()


func apply_changes() -> void:
	var error: Error = race.customization.save(vehicle, draft)
	if error != OK:
		status.text = "COULD NOT SAVE. PLEASE TRY AGAIN."
		status.add_theme_color_override("font_color", Style.CORAL)
		return
	saved = draft.duplicate(true)
	comparing = false
	race.apply_cosmetics()
	refresh()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()
