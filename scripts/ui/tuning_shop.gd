extends CanvasLayer
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
var race: Node3D
var frame: Control
var options: Control
var viewport: SubViewport
var car: Node3D
var summary: Label
var status: Label
var draft: Dictionary = {}
var saved: Dictionary = {}
var tab := 0
var tabs: Array[Button] = []
var comparing := false
var boost_demo := false
var vehicle := 0
var dragging := false
var closing_dialog: ConfirmationDialog


func _ready() -> void:
	layer = 30
	var background := ColorRect.new()
	background.color = Color("07121f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	frame = Control.new()
	frame.size = Vector2(1280, 720)
	add_child(frame)
	label("COAST CUSTOMS", Vector2(310, 25), 30)
	label("PAINT / LIVERY / WHEELS / REAR WING", Vector2(310, 65), 17)
	var back := button("< GARAGE", Rect2(30, 25, 230, 76), request_close)
	back.call_deferred("grab_focus")
	for i in range(4):
		var tab_button := button(
			["PAINT", "LIVERY", "WHEELS", "REAR WING"][i],
			Rect2(30 + (i % 2) * 134, 120 + (i / 2) * 82, 126, 76),
			func():
				tab = i
				build_options(),
			14
		)
		tab_button.toggle_mode = true
		tabs.append(tab_button)
	options = Control.new()
	options.position = Vector2(30, 292)
	frame.add_child(options)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 420) if race.lite_graphics else Vector2i(960, 630)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED if race.lite_graphics else Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	frame.add_child(viewport)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101e2c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bcd5e8")
	env.ambient_light_energy = .65
	world.environment = env
	viewport.add_child(world)
	for pose in [Vector3(-40, -35, 0), Vector3(-15, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = pose
		light.light_energy = 1.3 if pose.y < 0 else .5
		viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(-4, 2.2, -5.5)
	camera.fov = 35
	viewport.add_child(camera)
	camera.look_at(Vector3(0, .7, 0))
	car = Factory.create(vehicle)
	viewport.add_child(car)
	race.passport.apply_car(car, vehicle)
	car.reduced_motion = race.motion_reduced
	car.effects_quality = race.player.effects_quality
	var view := TextureRect.new()
	view.position = Vector2(315, 120)
	view.size = Vector2(650, 400)
	view.texture = viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.gui_input.connect(drag_preview)
	frame.add_child(view)
	summary = label("", Vector2(990, 160), 20)
	label("DRAG TO ROTATE", Vector2(510, 524), 17)
	button(
		"FRONT",
		Rect2(330, 548, 145, 76),
		func():
			car.rotation.y = 0
			redraw()
	)
	button(
		"SIDE",
		Rect2(485, 548, 145, 76),
		func():
			car.rotation.y = PI * .5
			redraw()
	)
	button(
		"REAR",
		Rect2(640, 548, 145, 76),
		func():
			car.rotation.y = PI
			redraw()
	)
	button("BOOST DEMO", Rect2(795, 548, 170, 76), func(): boost_demo = not boost_demo)
	button("CANCEL", Rect2(30, 634, 180, 76), discard)
	button(
		"FACTORY",
		Rect2(225, 634, 190, 76),
		func():
			draft = Store.defaults(vehicle)
			comparing = false
			build_options()
			refresh()
	)
	button(
		"COMPARE",
		Rect2(430, 634, 240, 76),
		func():
			comparing = not comparing
			refresh()
	)
	button("APPLY TO CAR", Rect2(930, 634, 320, 76), apply_changes)
	status = label("VISUAL TUNING / SAME DRIVING PERFORMANCE", Vector2(330, 100), 16)
	closing_dialog = ConfirmationDialog.new()
	closing_dialog.title = "Unsaved customization"
	closing_dialog.dialog_text = "Discard your changes and return to the garage?"
	closing_dialog.ok_button_text = "DISCARD"
	closing_dialog.cancel_button_text = "KEEP EDITING"
	closing_dialog.confirmed.connect(discard)
	frame.add_child(closing_dialog)
	build_options()
	refresh()


func label(text: String, at: Vector2, size_px: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_override("font", preload("res://assets/fonts/Roboto-BoldItalic.ttf"))
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", Color("b5d4e6"))
	frame.add_child(node)
	return node


func button(text: String, rect: Rect2, action: Callable, size_px: int = 18, parent: Control = null) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", size_px)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("183447")
	style.border_color = Color("28d5db")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	node.add_theme_stylebox_override("normal", style)
	node.pressed.connect(action)
	(parent if parent != null else frame).add_child(node)
	return node


func build_options() -> void:
	for i in range(tabs.size()):
		tabs[i].set_pressed_no_signal(i == tab)
	for child in options.get_children():
		child.free()
	if tab == 0:
		for i in range(2):
			var picker := ColorPickerButton.new()
			picker.position = Vector2(0, i * 86)
			picker.size = Vector2(260, 78)
			picker.text = "BODY COLOR" if i == 0 else "ACCENT COLOR"
			picker.edit_alpha = false
			picker.color = Color(draft.paint if i == 0 else draft.secondary)
			picker.color_changed.connect(
				func(color: Color): choose("paint" if i == 0 else "secondary", color.to_html(false))
			)
			options.add_child(picker)
		var finish := OptionButton.new()
		finish.position = Vector2(0, 182)
		finish.size = Vector2(260, 78)
		finish.add_theme_font_size_override("font_size", 20)
		for text in ["GLOSS PAINT", "MATTE PAINT", "METALLIC PAINT"]:
			finish.add_item(text)
		finish.selected = draft.finish
		finish.item_selected.connect(func(index: int): choose("finish", index))
		options.add_child(finish)
	elif tab == 1:
		for i in range(4):
			var choice := choice_button(
				["FACTORY PAINT", "HERITAGE STRIPES", "COAST WAVES", "CIRCUIT GRAPHIC"][i],
				Rect2(0, i * 82, 260, 76),
				"livery",
				i
			)
			if i > 0:
				var atlas := AtlasTexture.new()
				atlas.atlas = load(Custom.ATLAS)
				atlas.region = Rect2(
					Vector2(vehicle * atlas.atlas.get_width() / 4.0, (i - 1) * atlas.atlas.get_height() / 3.0),
					Vector2(atlas.atlas.get_width() / 4.0, atlas.atlas.get_height() / 3.0)
				)
				choice.icon = atlas
				choice.expand_icon = true
				choice.add_theme_constant_override("icon_max_width", 65)
	elif tab == 2:
		for i in range(3):
			choice_button(
				["FACTORY WHEELS", "FORGED FIVE SPOKE", "SPLIT SPOKE"][i], Rect2(0, i * 88, 260, 78), "wheel", i
			)
		var picker := ColorPickerButton.new()
		picker.position = Vector2(0, 254)
		picker.size = Vector2(260, 78)
		picker.text = "RIM COLOR"
		picker.edit_alpha = false
		picker.color = Color(draft.rim)
		picker.color_changed.connect(func(color: Color): choose("rim", color.to_html(false)))
		options.add_child(picker)
	else:
		for i in range(4):
			choice_button(
				["FACTORY AERO", "LOW DUCKTAIL", "GT REAR WING", "NO WING"][i], Rect2(0, i * 82, 260, 76), "wing", i
			)


func choice_button(text: String, rect: Rect2, key: String, value: int) -> Button:
	var node := button(text, rect, func(): choose(key, value), 18, options)
	node.toggle_mode = true
	node.set_meta("selection_key", key)
	node.set_meta("selection_value", value)
	node.set_pressed_no_signal(draft[key] == value)
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
	var data: Dictionary = saved if comparing else draft
	Custom.apply(car, data, vehicle)
	summary.text = (
		str(Catalog.spec(vehicle).name)
		+ "\n\n"
		+ ["GLOSS", "MATTE", "METALLIC"][data.finish]
		+ "\n\nLIVERY "
		+ str(data.livery)
		+ "\n\n"
		+ Custom.WHEELS[data.wheel].to_upper().replace("_", " ")
		+ "\n\n"
		+ Custom.WINGS[data.wing].to_upper().replace("_", " ")
		+ "\n\n"
		+ ("SAVED COMPARISON" if comparing else ("UNSAVED CHANGES" if draft != saved else "APPLIED"))
	)
	redraw()


func redraw() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func drag_preview(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventScreenTouch:
		dragging = event.pressed
	if (event is InputEventMouseMotion and dragging) or event is InputEventScreenDrag:
		car.rotation.y += event.relative.x * .008
		redraw()


func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := minf(size.x / 1280, size.y / 720)
	frame.scale = Vector2.ONE * factor
	frame.position = (size - Vector2(1280, 720) * factor) * .5
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
		closing_dialog.popup_centered(Vector2i(430, 200))
	else:
		discard()


func discard() -> void:
	race.tuning_shop = null
	queue_free()
	race.shell.sync_back()


func apply_changes() -> void:
	var error: Error = race.customization.save(vehicle, draft)
	if error != OK:
		status.text = "SAVE FAILED / CHANGES KEPT FOR RETRY"
		return
	saved = draft.duplicate(true)
	comparing = false
	race.apply_cosmetics()
	refresh()
	status.text = "CUSTOMIZATION SAVED"


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()
