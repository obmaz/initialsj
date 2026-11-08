extends Node3D
const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const HUD = preload("res://scripts/hud.gd")
const Library = preload("res://scripts/route_library.gd")
const Contact = preload("res://scripts/car_contact.gd")
const Brain = preload("res://scripts/rival_brain.gd")
const SurfaceState = preload("res://scripts/road_surface_state.gd")
const AirState = preload("res://scripts/air_state.gd")
const Features = preload("res://scripts/road_features.gd")
const Factory = preload("res://scripts/vehicle_factory.gd")
const Circuit = preload("res://scripts/circuit_track.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const Pad = preload("res://scripts/gamepad_input.gd")
const Nitro = preload("res://scripts/nitro_system.gd")
const RenderBudget = preload("res://scripts/render_budget.gd")
const WorldRace = preload("res://scripts/world_race.gd")
const Corner = preload("res://scripts/corner_resistance.gd")
const Crash = preload("res://scripts/crash_state.gd")
const Recovery = preload("res://scripts/recovery_state.gd")
var crash := Crash.new()
var recovery := Recovery.new()
var recovery_distance := 80.0
var recovery_lane := -3.2
var recovery_available: bool:
	get: return state == "racing" and recovery.available
const GAME_PACE := 1.2
const RECORD_GROUP := "coast_rush_v3"
var selected_vehicle := 0
var vehicle: Dictionary = Catalog.spec(0)
var previews: Node
var resume_state := "racing"
var nitro_charges := 0
var nitro_burst_left := 0.0
var nitro_cooldown := 0.0
var nitro_previous_input := false
var cell_previous_input := false
var nitro_pending := false
var cell_pending := false
var brain := Brain.new()
var track: Track
var player: Car
var atmosphere: Environment
var sky_colors: ProceduralSkyMaterial
var rim_light: DirectionalLight3D
var sun_light: DirectionalLight3D
var visual_theme := "hawaii"
var atmosphere_transition := 0.0
var camera: Camera3D
var hud: HUD
var speed_effect: ColorRect
var tire_trails: Node3D
var speed_ambience: Node3D
var impacts: Node3D
var rivals: Array[Dictionary] = []
var surface := SurfaceState.new()
var air := AirState.new()
var shoulder_dust: Node3D
var offroad_amount := 0.0
var shoulder_dust_clock := 0.0
var landing_dust: Node3D
var water_effect: Node3D
var pad_active: bool:
	get: return state == "racing" and not crash.active and (surface.pad_time > 0 or surface.lane_active) and not braking and impact < 0.15
var mode := "tour"
var graphics_mode := 0
var render_budget := RenderBudget.new()
var screen_transition: CanvasLayer
var warming_world := false
var camera_intro := 0.0
var selected_course := 0
var world_race: Node3D
var course_title: String:
	get: return "SUNCOAST SPEEDWAY" if selected_course == 1 else "FUJI LAKESIDE"
var course_label: String:
	get: return "SUNCOAST / CIRCUIT 02" if selected_course == 1 else "FUJI / CIRCUIT 01"
var settings_return := "menu"
# Shown on the loading card of the next screen transition (empty for an ordinary fade).
var loading_title := ""
# Low-memory rendering for consoles and browsers that already lost their GPU context.
var lite_graphics := false
# Short warning for the next gimmick on a Tour road (truck, steep drop, narrow road).
var hazard_text := ""
var laps_completed := 0
var lap_started := 0.0
var last_lap := 0.0
var state := "menu":
	set(value):
		state = value
		_sync_web_back()
		if state != "settings": _hide_fullscreen_control()
var distance := 80.0
var completed_distance := 0.0
var lane := -3.2
var speed := 0.0
var lane_velocity := 0.0
var steer := 0.0
var slip_angle := 0.0
var wall_assist := 0.0
var wall_side := 0.0
var elapsed := 0.0
var countdown := 3.0
var time_left := Library.START_TIME
var score := 0.0
var throttling := false
var braking := false
var drifting := false
var boosting := false
var nitro := 70.0
var nitro_active := false
var nitro_locked := false
var nitro_seconds := 0.0
var checkpoint_award := Library.CHECKPOINT_BONUS
var drift_previous_input := false
var drift_pending := 0.0
var drift_latched := false
var drift_sign := 0.0
var drift_straight := 0.0
var drift_charge := 0.0
var drifts_completed := 0
var brake_armed := 0.0
var previous_brake := false
var draft_charge := 0.0
var drafting := false
var recommended_speed := 80.0
var corner_warning := 0.0
var near_misses := 0
var near_miss_flash := 0.0
var overtakes := 0
var overtake_flash := 0.0
var checkpoint_flash := 0.0
var return_flash := 0.0
var hitstop_until := 0
var checkpoints := 0
var checkpoint_stage := -1
var route_preference := -1
var route_choice_flash := 0.0
var route_confirm_flash := 0.0
var route_confirm_title := ""
var wall_hits := 0
var traffic_hits := 0
var impact := 0.0
var impact_normal := Vector2.ZERO
var impact_recoil := 0.0
var impact_age := 1.0
var boost_kick := 0.0
var bump_cooldown := 0.0
var launch_flash := 0.0
var web_portrait := false
var web_orientation_callback: JavaScriptObject
var web_back_callback: JavaScriptObject
var web_fullscreen_callback: JavaScriptObject
var web_fullscreen_active := false
var web_dom_fullscreen_active := false
var web_back_after_fullscreen_until := 0
var fullscreen_control_rect := Rect2()
var fullscreen_control_visible := false
var fullscreen_return_mode := DisplayServer.WINDOW_MODE_WINDOWED
var motion_reduced := false
var motion_user_set := false
var pad := Pad.new()
var gamepad_active := false
var settings_focus := 0
var preferences_path := "user://settings.cfg"
var sound_enabled := true
var camera_time := 0.0
var camera_offset := Vector3.ZERO
var best_time := 0.0
# Set when a run ends: the best before it, and whether this run beat it.
var previous_best := 0.0
var new_record := false
var save_records := true
var stage_index: int:
	get: return track.active.stage
var route_node: int:
	get: return track.active.route_node
var journey_distance: float:
	get: return completed_distance + distance - 80

func _ready() -> void:
	track = Track.new()
	add_child(track)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	atmosphere = env
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_colors = sky_material
	sky_material.sky_top_color = Color("438cce")
	sky_material.sky_horizon_color = Color("cce5e9")
	sky_material.ground_bottom_color = Color("688370")
	sky_material.ground_horizon_color = Color("c3d9db")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5cce0")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color("b3d3df")
	env.fog_density = 0.00065
	env.fog_sky_affect = 0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun_light = sun
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-18,145,0)
	rim_light.light_color = Color("a1bce8")
	rim_light.light_energy = 0.10
	rim_light.shadow_enabled = false
	rim_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(rim_light)
	tire_trails = preload("res://scripts/tire_trails.gd").new()
	add_child(tire_trails)
	speed_ambience = preload("res://scripts/speed_ambience.gd").new()
	add_child(speed_ambience)
	water_effect = preload("res://scripts/water_splash.gd").new()
	add_child(water_effect)
	landing_dust = preload("res://scripts/landing_dust.gd").new()
	add_child(landing_dust)
	shoulder_dust = preload("res://scripts/landing_dust.gd").new()
	add_child(shoulder_dust)
	impacts = preload("res://scripts/impact_effect.gd").new()
	add_child(impacts)
	player = Factory.create(selected_vehicle)
	add_child(player)
	var colors := ["e7c456","91aabe","aaa3b7","e8e5dc","4c9c97","ad6f55","62798c"]
	for i in range(16):
		var car := Car.new()
		car.traffic = true
		car.paint = Color(colors[i % colors.size()])
		add_child(car)
		rivals.append({"car":car})
	initialize_traffic()
	camera = Camera3D.new()
	camera.far = 1800
	camera.fov = 68
	add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	speed_effect = ColorRect.new()
	speed_effect.visible = false
	speed_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://shaders/speed_blur.gdshader")
	speed_effect.material = effect
	canvas.add_child(speed_effect)
	hud = HUD.new()
	hud.race = self
	canvas.add_child(hud)
	if DisplayServer.get_name() != "headless":
		screen_transition = preload("res://scripts/screen_transition.gd").new()
		screen_transition.race = self
		add_child(screen_transition)
	if DisplayServer.get_name() != "headless":
		if OS.has_feature("web"):
			lite_graphics = bool(JavaScriptBridge.eval("window.initialsjLiteGraphics ? window.initialsjLiteGraphics() : false"))
		previews = preload("res://scripts/garage_previews.gd").new()
		previews.lite = lite_graphics
		add_child(previews)
		for index in range(Catalog.SPECS.size()): previews.show_vehicle(index)
		var audio = preload("res://scripts/racing_audio.gd").new()
		audio.race = self
		add_child(audio)
		if OS.has_feature("web"):
			motion_reduced = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))
	load_preferences()
	render_budget.set_mode(graphics_mode,self)
	load_record()
	reset_nitro()
	place_cars()
	update_camera(1)
	if OS.has_feature("web"):
		web_orientation_callback = JavaScriptBridge.create_callback(_on_web_orientation)
		JavaScriptBridge.get_interface("window").initialsjObserveOrientation(web_orientation_callback)
		web_back_callback = JavaScriptBridge.create_callback(_on_web_back)
		JavaScriptBridge.get_interface("window").initialsjObserveBack(web_back_callback,state != "menu")
		web_fullscreen_callback = JavaScriptBridge.create_callback(_on_web_fullscreen)
		JavaScriptBridge.get_interface("window").initialsjObserveFullscreen(web_fullscreen_callback)
	elif OS.has_feature("android"):
		get_tree().quit_on_go_back = false
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if OS.has_feature("web"): _announce_ready()

# The page keeps its loading screen until the first menu frames are drawn.
func _announce_ready() -> void:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("window.initialsjGameReady && window.initialsjGameReady()")

func _on_web_fullscreen(args: Array) -> void:
	var active: bool = bool(args[0])
	var dom_active: bool = bool(args[1])
	var exited: bool = (web_fullscreen_active and not active) or (web_dom_fullscreen_active and not dom_active)
	web_fullscreen_active = active
	web_dom_fullscreen_active = dom_active
	# Android Back can leave browser fullscreen before dispatching popstate.
	if exited and state in ["racing","countdown","paused"]:
		pause_tour()
		# Some browser versions emit both fullscreenchange and popstate for
		# one Back gesture; do not let the second event immediately resume.
		web_back_after_fullscreen_until = Time.get_ticks_msec()+350

func is_fullscreen() -> bool:
	if OS.has_feature("web"): return bool(JavaScriptBridge.eval("window.initialsjIsFullscreen && window.initialsjIsFullscreen()"))
	if DisplayServer.get_name() == "headless": return false
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func fullscreen_label() -> String:
	if OS.has_feature("web"): return str(JavaScriptBridge.eval("window.initialsjFullscreenLabel ? window.initialsjFullscreenLabel() : 'ENTER FULLSCREEN'"))
	return "EXIT FULLSCREEN" if is_fullscreen() else "ENTER FULLSCREEN"

func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.initialsjToggleFullscreen && window.initialsjToggleFullscreen()")
	elif DisplayServer.get_name() != "headless":
		if is_fullscreen(): DisplayServer.window_set_mode(fullscreen_return_mode)
		else:
			fullscreen_return_mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _hide_fullscreen_control() -> void:
	if not fullscreen_control_visible: return
	fullscreen_control_visible = false
	if OS.has_feature("web"): JavaScriptBridge.get_interface("window").initialsjFullscreenControl(false,0,0,0,0)

func sync_fullscreen_button(design_rect: Rect2) -> void:
	if not OS.has_feature("web"): return
	if state != "settings" or (screen_transition != null and screen_transition.busy):
		_hide_fullscreen_control()
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var rect := Rect2((design_rect.position*hud.ui_scale()+hud.ui_offset())/viewport_size,design_rect.size*hud.ui_scale()/viewport_size)
	if fullscreen_control_visible and fullscreen_control_rect.is_equal_approx(rect): return
	fullscreen_control_visible = true
	fullscreen_control_rect = rect
	JavaScriptBridge.get_interface("window").initialsjFullscreenControl(true,rect.position.x,rect.position.y,rect.size.x,rect.size.y)

func _sync_web_back() -> void:
	if web_back_callback != null:
		var transitioning: bool = screen_transition != null and screen_transition.busy
		JavaScriptBridge.get_interface("window").initialsjSetBackEnabled(state != "menu" or transitioning)

func _on_web_back(_args: Array) -> void:
	navigate_back()

# Keep hardware/browser Back consistent with the visible screen's back action.
# Repeated Back during a transition is consumed rather than queued.
func navigate_back() -> bool:
	if Time.get_ticks_msec() < web_back_after_fullscreen_until: return true
	if screen_transition != null and screen_transition.busy: return true
	match state:
		"racing", "countdown": pause_tour()
		"paused": resume_tour()
		"ready": navigate(open_courses if mode == "track" else open_menu)
		"courses": navigate(open_menu)
		"settings": navigate(close_settings)
		"finished", "failed": navigate(open_garage)
		_: return false
	return true

func _on_web_orientation(args: Array) -> void:
	web_portrait = bool(args[0])
	if web_portrait:
		hud.fingers.clear()
		pause_tour()

func _exit_tree() -> void:
	_hide_fullscreen_control()
	Engine.time_scale = 1.0
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").initialsjObserveOrientation(null)
		JavaScriptBridge.get_interface("window").initialsjObserveBack(null,false)
		JavaScriptBridge.get_interface("window").initialsjObserveFullscreen(null)
		web_back_callback = null
		web_fullscreen_callback = null

func initialize_traffic() -> void:
	brain.initialize(rivals)
	if mode == "track":
		for r in rivals:
			r.active = r.id < 7
			r.distance = 95.0+int(r.id/2)*10
			r.lane = -2.0 if r.id%2 == 0 else 2.0
			r.target_lane = r.lane
			r.speed = 0.0
			r.pace = vehicle.max_speed*(0.94+r.id*0.018)

func navigate(action: Callable) -> void:
	_hide_fullscreen_control()
	if screen_transition == null:
		loading_title = ""
		action.call()
	else:
		if web_back_callback != null: JavaScriptBridge.get_interface("window").initialsjSetBackEnabled(true)
		await screen_transition.play(action)
		_sync_web_back()

func start_race() -> void:
	navigate(func():
		restart()
		camera_intro = 0.0 if motion_reduced else 1.0
		if camera_intro > 0:
			var f := (track.point(distance+3)-track.point(distance)).normalized()
			camera_offset += -f*3.5+Vector3.UP*2.0
			camera.position = player.position+camera_offset
			camera.reset_physics_interpolation()
	)

func cycle_graphics() -> void:
	graphics_mode = (graphics_mode+1)%3
	render_budget.set_mode(graphics_mode,self)

func open_courses() -> void:
	hud.fingers.clear()
	state = "courses"

func mode_loading_title(value: String, course: int = 0) -> String:
	if value != "track": return "COAST TOUR"
	return "SUNCOAST SPEEDWAY" if course == 1 else "FUJI LAKESIDE"

# Opens a mode through the transition, with a loading card when the course must be rebuilt.
func navigate_to_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if not (mode == desired and (desired == "tour" or selected_course == clampi(course,0,1))):
		loading_title = mode_loading_title(value,course)
	navigate(func(): choose_mode(value,course))

func choose_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if mode == desired and (desired == "tour" or selected_course == clampi(course,0,1)):
		open_garage()
		load_record()
		return
	if world_race != null:
		world_race.shutdown()
		remove_child(world_race)
		world_race.queue_free()
		world_race = null
	mode = "track" if value == "track" else "tour"
	selected_course = clampi(course,0,1)
	remove_child(track)
	track.queue_free()
	track = Circuit.new() if mode == "track" else Track.new()
	if mode == "track": track.course_id = selected_course
	add_child(track)
	if mode == "track":
		atmosphere.sky = track.scenery.make_sky()
		atmosphere.fog_light_color = Color("b3d3df")
		sun_light.light_energy = 1.0
		sun_light.light_color = Color("ffe4be")
		rim_light.light_energy = 0.10
		atmosphere.ambient_light_energy = 0.28
	else:
		var sky := Sky.new()
		sky.sky_material = sky_colors
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		atmosphere.sky = sky
		visual_theme = ""
	if mode == "track" and selected_course == 0:
		world_race = WorldRace.new()
		world_race.race = self
		add_child(world_race)
		world_race.setup()
	render_budget.apply(self)
	state = "ready"
	open_garage()
	load_record()

func open_menu() -> void:
	cancel_nitro()
	hud.fingers.clear()
	state = "menu"

func open_settings() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.initialsjPrepareInstall && window.initialsjPrepareInstall()")
	settings_return = state
	hud.fingers.clear()
	state = "settings"

func close_settings() -> void:
	state = settings_return
	save_preferences()

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) == OK:
		sound_enabled = bool(config.get_value("preferences","sound",true))
		# Only a stored choice overrides the system reduced-motion preference.
		if config.has_section_key("preferences","reduced_motion"):
			motion_reduced = bool(config.get_value("preferences","reduced_motion"))
			motion_user_set = true
		graphics_mode = clampi(int(config.get_value("preferences","graphics",0)),0,2)

func save_preferences() -> void:
	if not save_records: return
	var config := ConfigFile.new()
	config.set_value("preferences","sound",sound_enabled)
	if motion_user_set: config.set_value("preferences","reduced_motion",motion_reduced)
	config.set_value("preferences","graphics",graphics_mode)
	config.save(preferences_path)

# Every screen that offers these switches goes through here, so a choice made on
# the pause or result dialog survives a reload like one made in Settings.
func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	save_preferences()

func toggle_motion() -> void:
	motion_reduced = not motion_reduced
	motion_user_set = true
	save_preferences()

func relative_gap(other: float, reference: float) -> float:
	return wrapf(other-reference,-track.length/2,track.length/2) if mode == "track" else other-reference

func race_position() -> int:
	return competitor_position(-1)

func competitor_position(id: int) -> int:
	var progress: float = distance if id < 0 else rivals[id].distance
	var place := 1
	if id >= 0 and distance > progress+0.001: place += 1
	for r in rivals:
		if not r.active or r.id == id: continue
		if r.distance > progress+0.001 or (absf(r.distance-progress) <= 0.001 and r.id > id): place += 1
	return place

func restart() -> void:
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0,player.ride_offset,0)
	recovery_distance = 80
	recovery_lane = -3.2
	if mode == "tour" and (track.active.stage != 0 or not track.history.is_empty()): track.reset()
	distance = 80
	completed_distance = 0
	lane = -3.2
	speed = 0
	lane_velocity = 0
	steer = 0
	slip_angle = 0
	wall_assist = 0
	elapsed = 0
	laps_completed = 0
	lap_started = 0
	last_lap = 0
	countdown = 3
	time_left = Library.START_TIME
	score = 0
	surface.reset()
	offroad_amount = 0
	shoulder_dust_clock = 0
	air.reset()
	throttling = false
	braking = false
	drifting = false
	boosting = false
	reset_nitro()
	hud.fingers.clear()
	checkpoint_award = Library.CHECKPOINT_BONUS
	drift_previous_input = false
	drift_pending = 0
	drift_latched = false
	drift_sign = 0
	drift_straight = 0
	drift_charge = 0
	drifts_completed = 0
	brake_armed = 0
	previous_brake = false
	draft_charge = 0
	drafting = false
	near_misses = 0
	near_miss_flash = 0
	overtakes = 0
	overtake_flash = 0
	checkpoint_flash = 0
	checkpoints = 0
	checkpoint_stage = -1
	route_preference = -1
	route_choice_flash = 0
	route_confirm_flash = 0
	wall_hits = 0
	traffic_hits = 0
	impact = 0
	impact_normal = Vector2.ZERO
	impact_recoil = 0
	impact_age = 1
	hitstop_until = 0
	return_flash = 0
	impacts.reset()
	boost_kick = 0
	bump_cooldown = 0
	launch_flash = 0
	camera_offset = Vector3.ZERO
	camera_intro = 0
	state = "countdown"
	initialize_traffic()
	if world_race != null: world_race.reset()
	tire_trails.reset()
	place_cars()
	update_camera(1)
	player.reset_physics_interpolation()
	camera.reset_physics_interpolation()
	for r in rivals: r.car.reset_physics_interpolation()
	# A screen transition can finish after the device rotated to portrait. The
	# rotate guide hides the road, so wait paused rather than run unseen.
	if web_portrait: pause_tour()

func _input(event: InputEvent) -> void:
	if Pad.is_pad_event(event):
		# State is always tracked, so a button released during a transition cannot stick.
		if pad.handle(event): gamepad_active = true
		var blocked: bool = (screen_transition != null and screen_transition.busy) or web_portrait
		if event is InputEventJoypadButton and event.pressed and not blocked: pad_pressed(event.button_index)
		return
	if (event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed: gamepad_active = false
	if screen_transition != null and screen_transition.busy: return
	if web_portrait: return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventKey and event.pressed and not event.echo:
		if state == "menu":
			if event.keycode in [KEY_ENTER,KEY_1,KEY_T]: navigate_to_mode("tour")
			elif event.keycode in [KEY_2,KEY_C]: navigate(open_courses)
			elif event.keycode == KEY_TAB: navigate(open_settings)
			return
		if state == "courses":
			if event.keycode in [KEY_1,KEY_ENTER]: navigate_to_mode("track",0)
			elif event.keycode == KEY_2: navigate_to_mode("track",1)
			elif event.keycode == KEY_ESCAPE: navigate(open_menu)
			return
		if state == "settings":
			if event.keycode in [KEY_ESCAPE,KEY_TAB]: navigate(close_settings)
			return
		if state == "ready" and event.keycode == KEY_ESCAPE:
			if mode == "track": navigate(open_courses)
			else: navigate(open_menu)
			return
		if event.keycode == KEY_ENTER:
			if state == "ready": start_race()
			elif state in ["finished","failed"]: navigate(open_garage)
		elif state == "ready" and event.keycode >= KEY_1 and event.keycode < KEY_1+Catalog.SPECS.size(): select_vehicle(event.keycode-KEY_1)
		elif state == "ready" and event.keycode in [KEY_A,KEY_LEFT]: select_vehicle(posmod(selected_vehicle-1,Catalog.SPECS.size()))
		elif state == "ready" and event.keycode in [KEY_D,KEY_RIGHT]: select_vehicle((selected_vehicle+1)%Catalog.SPECS.size())
		elif event.keycode == KEY_V: toggle_sound()
		elif event.keycode == KEY_M: toggle_motion()
		elif event.keycode == KEY_R and state != "ready": start_race()
		elif event.keycode == KEY_G and state == "paused": navigate(open_menu)
		elif event.keycode in [KEY_ESCAPE,KEY_P]:
			if state == "paused": resume_tour()
			else: pause_tour()
	if event is InputEventScreenTouch or event is InputEventMouseButton: hud.handle_pointer(event)
	if event is InputEventScreenDrag: hud.move_pointer(event.index,event.position)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): hud.move_pointer(-1,event.position)

# A pad button press, mapped like the keyboard shortcuts of the same screen.
func pad_pressed(button: int) -> void:
	var count := Catalog.SPECS.size()
	match state:
		"menu":
			match button:
				JOY_BUTTON_A: navigate_to_mode("tour")
				JOY_BUTTON_X: navigate(open_courses)
				JOY_BUTTON_Y: navigate(open_settings)
		"courses":
			match button:
				JOY_BUTTON_A: navigate_to_mode("track",0)
				JOY_BUTTON_X: navigate_to_mode("track",1)
				JOY_BUTTON_B: navigate(open_menu)
		"settings":
			match button:
				JOY_BUTTON_DPAD_UP: settings_focus = posmod(settings_focus-1,SETTINGS_ROWS)
				JOY_BUTTON_DPAD_DOWN: settings_focus = posmod(settings_focus+1,SETTINGS_ROWS)
				JOY_BUTTON_A: settings_activate(settings_focus)
				JOY_BUTTON_B, JOY_BUTTON_START: navigate(close_settings)
		"ready":
			match button:
				JOY_BUTTON_A, JOY_BUTTON_START: start_race()
				JOY_BUTTON_B: navigate(open_courses if mode == "track" else open_menu)
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT: select_vehicle(posmod(selected_vehicle-1,count))
				JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT: select_vehicle((selected_vehicle+1)%count)
		"racing","countdown":
			match button:
				JOY_BUTTON_START, JOY_BUTTON_BACK: pause_tour()
				JOY_BUTTON_Y: recover_car()
				JOY_BUTTON_LEFT_SHOULDER: select_route(0)
				JOY_BUTTON_RIGHT_SHOULDER: select_route(1)
		"paused":
			match button:
				JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK: resume_tour()
				JOY_BUTTON_X: navigate(open_menu)
				JOY_BUTTON_Y: start_race()
		"finished","failed":
			match button:
				JOY_BUTTON_A: navigate(open_garage)
				JOY_BUTTON_X, JOY_BUTTON_BACK: start_race()

const SETTINGS_ROWS := 6
func settings_activate(index: int) -> void:
	match index:
		0: toggle_sound()
		1: toggle_motion()
		2: cycle_graphics()
		3: toggle_fullscreen()
		4: hud.install_game()
		_: navigate(close_settings)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected: return
	# A pad that disappears mid-race must not leave the car steering or boosting on its own.
	pad.clear()
	if Input.get_connected_joypads().is_empty(): gamepad_active = false
	pause_tour()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not navigate_back() and OS.has_feature("android"): get_tree().quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if hud != null: hud.fingers.clear()
		pad.clear()
		pause_tour()

func pause_tour() -> void:
	if state in ["racing","countdown"]:
		resume_state = state
		state = "paused"
		if hud != null: hud.fingers.clear()

func resume_tour() -> void:
	if web_portrait: return
	if state == "paused":
		hud.fingers.clear()
		state = resume_state

func load_record() -> void:
	best_time = 0
	previous_best = 0
	new_record = false
	var saved := ConfigFile.new()
	if saved.load("user://records.cfg") == OK: best_time = float(saved.get_value(RECORD_GROUP,Catalog.record_key(selected_vehicle,mode,selected_course),0))

func select_vehicle(index: int) -> void:
	if state != "ready": return
	if selected_vehicle == clampi(index,0,Catalog.SPECS.size()-1): return
	var old_index := selected_vehicle
	selected_vehicle = clampi(index,0,Catalog.SPECS.size()-1)
	hud.vehicle_changed(old_index)
	vehicle = Catalog.spec(selected_vehicle)
	remove_child(player)
	player.queue_free()
	player = Factory.create(selected_vehicle)
	add_child(player)
	reset_nitro()
	load_record()
	if world_race != null: world_race.reset()
	place_cars()
	update_camera(1)
	if previews != null: previews.show_vehicle(selected_vehicle)

func open_garage() -> void:
	restart()
	state = "ready"
	if previews != null: previews.show_vehicle(selected_vehicle)

func reset_nitro() -> void:
	nitro = vehicle.energy_start
	nitro_charges = vehicle.charges
	nitro_seconds = 0
	nitro_locked = false
	nitro_previous_input = false
	cell_previous_input = false
	nitro_cooldown = 0
	cancel_nitro()

func cancel_nitro() -> void:
	surface.cancel_boost()
	boost_kick = 0
	nitro_active = false
	nitro_burst_left = 0
	nitro_pending = false
	cell_pending = false
	boosting = false

func gear_number() -> int:
	if world_race != null and world_race.reversing: return -1
	if speed < 0.3: return 0
	return clampi(ceili(speed/(vehicle.max_speed/5.8)),1,6)

func engine_rpm() -> float:
	if state in ["menu","courses","ready","settings","finished","failed"]: return 0
	var band: float = vehicle.max_speed/5.8
	var gear := maxi(1,gear_number())
	var progress := clampf((speed-(gear-1)*band)/band,0,1)
	return clampf(900+progress*6400,900,7500)

func nitro_ratio() -> float:
	if vehicle.mode == "charges": return (nitro_charges+nitro_burst_left/vehicle.burst_duration)/vehicle.charges
	return nitro/100

func _physics_process(delta: float) -> void:
	Engine.time_scale = (GAME_PACE if state in ["racing","countdown"] else 1.0)*(0.15 if Time.get_ticks_msec() < hitstop_until else 1.0)
	return_flash = maxf(0,return_flash-delta)
	update_atmosphere(delta)
	if state == "countdown":
		countdown -= delta
		if countdown <= 0:
			state = "racing"
			launch_flash = 0.7
	if state == "racing":
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		axis = clampf(axis + hud.touch_axis() + pad.steer(),-1,1)
		var nitro_input := Input.is_physical_key_pressed(KEY_SHIFT) or hud.held("nitro") or pad.nitro()
		var cell_input := Input.is_physical_key_pressed(KEY_E) or hud.held("cell") or pad.cell()
		var gas := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or hud.held("gas") or pad.gas() or nitro_input
		var brake := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or hud.held("brake") or pad.brake()
		step(delta,axis,Input.is_physical_key_pressed(KEY_SPACE) or hud.held("drift") or pad.drift(),gas,brake,nitro_input,cell_input)
	place_cars(delta)
	var world_visible := warming_world or state not in ["menu","courses","ready","settings"]
	track.visible = world_visible
	player.visible = world_visible
	tire_trails.visible = world_visible
	if not world_visible:
		for r in rivals: r.car.visible = false
	shoulder_dust_clock = maxf(0,shoulder_dust_clock-delta)
	shoulder_dust.visible = world_visible and state == "racing"
	if state == "racing" and offroad_amount > 0.25 and speed > 12 and not air.active:
		if shoulder_dust_clock <= 0:
			shoulder_dust.burst(player.position if world_race != null else track.point(distance-2,lane),true)
			shoulder_dust_clock = 0.24
	else: shoulder_dust.particles.emitting = false
	tire_trails.update(self)
	speed_ambience.update(self)
	speed_effect.visible = state == "racing" and not motion_reduced and speed > 35 and render_budget.level < 2
	speed_effect.material.set_shader_parameter("strength",clampf((speed-35)/53*1.2,0,1))
	speed_effect.material.set_shader_parameter("high_quality",render_budget.level == 0)
	update_camera(delta)
	player.road_speed = speed if state == "racing" else 0.0
	player.animate(steer,drifting and state == "racing",(nitro_active or pad_active) and state == "racing",delta,0.0 if world_race != null else slip_angle,braking and state == "racing",impact if state == "racing" and not motion_reduced else 0.0)
	if crash.active:
		apply_crash_pose()
	if offroad_amount > 0.2:
		for particles in player.smoke: particles.emitting = false
	if player.headlight != null: player.headlight.visible = track.active.in_tunnel(distance) or track.scenery.theme == "neon"
	for r in rivals:
		if not r.active or not r.car.visible or absf(relative_gap(r.distance,distance)) > 145:
			if r.get("visual_running",true): r.car.animate(0,false,false,0)
			r.visual_running = false
			continue
		r.visual_running = true
		r.car.road_speed = r.speed if state == "racing" else 0.0
		r.car.animate(clampf((r.target_lane-r.lane)/2,-1,1),r.active and r.drifting and r.car.visible and absf(relative_gap(r.distance,distance)) < 80 and state == "racing",r.boosting and state == "racing",delta,r.visual_yaw)
	hud.queue_redraw()

func step(delta: float, axis: float, drift_input: bool, gas: bool, brake: bool, nitro_input: bool = false, cell_input: bool = false) -> void:
	if crash.advance(delta):
		player.body.rotation.x = 0
		player.body.rotation.z = 0
		player.body.position = Vector3(0,player.ride_offset,0)
	update_recovery(delta)
	if crash.active:
		axis = 0
		drift_input = false
		gas = false
		brake = false
		nitro_input = false
		cell_input = false
	if world_race != null:
		world_race.step(delta,axis,drift_input,gas,brake,nitro_input,cell_input)
		return
	# Advance only the time still available; a later checkpoint cannot revive an expired run.
	if mode == "tour": delta = minf(delta,time_left)
	if delta <= 0:
		state = "failed"
		cancel_nitro()
		drifting = false
		return
	axis = route_axis(axis)
	var shoulder := clampf((absf(lane)+0.8-track.half_width(distance))/1.6,0,1) if not air.active else 0.0
	offroad_amount = move_toward(offroad_amount,shoulder,delta*6)
	surface.update_lane(track.active,Vector2(lane,distance),speed,brake,impact,not air.active and not crash.active)
	gas = gas or nitro_input or (cell_input and vehicle.mode == "hybrid") or nitro_burst_left > 0 or surface.pad_time > 0 or surface.lane_active
	var old_surface_position := Vector2(lane,distance)
	elapsed += delta
	if mode == "tour": time_left = maxf(0,time_left-delta)
	for field in ["near_miss_flash","overtake_flash","checkpoint_flash","launch_flash","route_choice_flash","route_confirm_flash"]:
		set(field,maxf(0,float(get(field))-delta))
	impact = maxf(0,impact-delta*3.5)
	impact_age += delta
	surface.tick(delta,brake,impact)
	boost_kick = maxf(0,boost_kick-delta*2)
	bump_cooldown = maxf(0,bump_cooldown-delta)
	brake_armed = maxf(0,brake_armed-delta)
	throttling = gas and not brake
	braking = brake
	var steer_input := signf(axis)*pow(absf(axis),1.22)
	steer = move_toward(steer,steer_input,delta*vehicle.steer_rate*0.9*lerpf(1,0.75,surface.wetness))
	if brake and not previous_brake and speed > 25: brake_armed = 0.45
	var was_drifting := drifting
	var drift_pressed := drift_input and not drift_previous_input
	drift_previous_input = drift_input
	drift_pending = maxf(0,drift_pending-delta)
	var end_drift := drift_pressed and drift_latched
	if end_drift:
		drift_latched = false
		drift_pending = 0
	elif drift_pressed: drift_pending = 0.55
	if not end_drift and speed > 25 and absf(steer) > 0.2 and (drift_pending > 0 or (previous_brake and brake_armed > 0 and gas)):
		if not drift_latched: drift_sign = signf(steer)
		drift_latched = true
		drift_pending = 0
	if air.active or speed < 22 or (brake and absf(steer) < 0.14):
		drift_latched = false
		if brake: drift_pending = 0
	var curve := track.curvature(distance)
	if drift_latched and absf(steer) < 0.14 and absf(curve)*speed*speed < vehicle.grip*surface.grip_factor*0.75:
		drift_straight += delta
		if drift_straight > 0.4: drift_latched = false
	else: drift_straight = 0
	drifting = drift_latched
	previous_brake = brake
	if drifting: drift_charge = minf(3,drift_charge+delta)
	elif was_drifting:
		if drift_charge > 0.55 and absf(lane) < track.half_width(distance)-1:
			drifts_completed += 1
		drift_charge = 0
	var desired_yaw := ((-drift_sign*0.30-steer*0.30) if drifting else -steer*0.07)-clampf(lane_velocity*0.022,-0.16,0.16)*surface.wetness
	if wall_assist > 0:
		# After a rail hit the nose settles slightly toward the road instead of back at the wall.
		wall_assist = maxf(0,wall_assist-delta)
		desired_yaw = lerpf(desired_yaw,0.0,clampf(wall_assist/0.5,0,1))
	slip_angle = lerp_angle(slip_angle,desired_yaw,1-exp(-delta*6))
	var old_gaps: Array[float] = []
	drafting = false
	for r in rivals:
		var gap: float = relative_gap(r.distance,distance)
		old_gaps.append(gap)
		if r.active and r.detached == null and gap > 8 and gap < 75 and absf(r.lane-lane) < 2.1 and absf(air.height-float(r.air.height)) < 1.5: drafting = true
	draft_charge = move_toward(draft_charge,1.0 if drafting else 0.0,delta*(1.0 if drafting else 1.2))
	Nitro.update(self,delta,nitro_input,cell_input)
	var was_boosting := boosting
	boosting = nitro_active or pad_active or (draft_charge > 0.65 and throttling and not drifting and impact < 0.15)
	if boosting and not was_boosting: boost_kick = 0.35
	var grip: float = ((vehicle.drift_grip if drifting else vehicle.grip)+track.active.banking_grip(distance))*surface.grip_factor*lerpf(1,0.72,offroad_amount)
	var demand := absf(curve) * speed * speed
	var excess := maxf(0,demand-grip)
	# Past the tyre limit ordinary steering loses authority quickly; a drift's
	# higher grip is the way to hold a fast, tight line.
	var authority := clampf(1-excess/(grip*1.4),0.22,1)
	if mode == "tour":
		# Loaded front tyres need braking before a fast bend. Straight slalom
		# response and low-speed steering retain their full authority.
		var loaded := smoothstep(0.45,1.2,demand/maxf(grip,1))*smoothstep(35,70,speed)
		authority *= lerpf(1,0.72,loaded)
	var outward := signf(curve) * (demand * 0.055 + excess * (1.6 if drifting else 2.3))
	var steering_scale := lerpf(1,0.86,smoothstep(35,85,speed))
	var lateral: float = steer * steering_scale * (vehicle.drift_steer_speed if drifting else vehicle.steer_speed) * minf(speed/20,1) * authority + outward
	if air.active: lateral = lane_velocity+steer*delta*3.0
	var next_lane_velocity := move_toward(lane_velocity,lateral,delta*(vehicle.lateral_drift if drifting else vehicle.lateral_grip)*surface.lateral_factor)
	# Lane changes load the tyres while changing direction and sliding sideways.
	# Use actual motion: an input at rest or an airborne turn adds no tyre drag.
	var lane_load := Vector2(absf(next_lane_velocity-lane_velocity)/delta*0.4,absf(next_lane_velocity)*1.1).length()
	var corner_demand := Vector2(demand,lane_load).length()
	lane_velocity = next_lane_velocity
	if brake: speed = move_toward(speed,0,delta*vehicle.brake)
	elif not gas: speed = move_toward(speed,0,delta*5)
	elif drifting:
		speed = move_toward(speed,pad_speed_cap(),delta*(vehicle.boost_accel+12)*0.75) if pad_active else maxf(0,speed-delta*0.35)
	else:
		var cap: float = (vehicle.overdrive_speed if nitro_burst_left > 0 else vehicle.boost_speed) if nitro_active else vehicle.max_speed+draft_charge*8
		var acceleration: float = vehicle.boost_accel if nitro_active else vehicle.accel
		if pad_active:
			cap = maxf(cap,pad_speed_cap())
			acceleration = maxf(acceleration,vehicle.boost_accel+12)
		cap *= lerpf(1,0.58,offroad_amount)
		# Loaded tyres spend some of the available force turning. Near top speed
		# the engine cannot replace all corner scrub each frame; boost still has
		# its own higher cap and stronger acceleration when exiting the bend.
		if not air.active: acceleration *= Corner.engine_factor(speed,cap,corner_demand,grip)
		speed = move_toward(speed,cap,delta*acceleration)
	speed = maxf(0,speed-delta*10*offroad_amount)
	if not air.active:
		speed = maxf(0,speed-delta*Corner.loss_rate(speed,corner_demand,grip,slip_angle,drifting))
	lane += lane_velocity*delta
	var limits := track.lane_limits(distance)
	var radius := Contact.HALF_WIDTH * absf(cos(slip_angle)) + Contact.HALF_LENGTH * absf(sin(slip_angle))
	limits += Vector2(radius-Contact.HALF_WIDTH,-radius+Contact.HALF_WIDTH)
	var margin := minf(lane-limits.x,limits.y-lane)
	if margin < 1.0: speed = move_toward(speed,minf(speed,38),delta*32)
	if lane < limits.x or lane > limits.y:
		var side := -1.0 if lane < limits.x else 1.0
		var incoming_speed := speed
		var closing_speed := absf(lane_velocity)
		lane = clampf(lane,limits.x,limits.y)
		# The bounce follows how fast the car hit, not just how fast it drifted sideways.
		var launching := Crash.launches(incoming_speed)
		if launching:
			var bounce := maxf(closing_speed,incoming_speed*0.22)
			lane_velocity = -side*clampf(bounce*0.9,2.0,24)
			slip_angle += -side*clampf(incoming_speed*0.012,0,0.7)
		else:
			# No bounce below the launch speed: the car barely leaves the rail and its nose is
			# swung parallel to it while it scrapes along.
			lane_velocity = -side*clampf(closing_speed*0.12,0.3,2.5)
			slip_angle = lerp_angle(slip_angle,0.0,0.65)
			wall_assist = 0.9
			wall_side = side
		if bump_cooldown <= 0:
			wall_hits += 1
			var scrape_speed := maxf(speed,absf(lane_velocity)*3)
			speed *= lerpf(0.88,0.5,clampf(incoming_speed/70.0,0,1)) if launching else lerpf(0.97,0.86,clampf(incoming_speed/Crash.LAUNCH_SPEED,0,1))
			register_impact(smoothstep(2.5,72,scrape_speed)*0.9,Vector2(-side,0))
			if Crash.launches(incoming_speed) and not crash.active:
				var up := Crash.launch_up(incoming_speed)
				crash.start(incoming_speed,Vector2(-side,0),0.0,2.0*up/air.GRAVITY)
				air.active = true
				air.trick = false
				air.world_y = track.point(distance,lane).y+0.15
				air.height = 0.15
				air.velocity = up
	distance += speed*delta
	var was_airborne := air.active
	var flight_events: Array[String] = air.advance(track.active,old_surface_position,Vector2(lane,distance),speed,delta)
	for event in flight_events:
		if event in ["launch","drop"]:
			drifting = false
			drift_latched = false
			drift_charge = 0
		elif event == "land" and air.trick:
			score += 100
			if DisplayServer.get_name() != "headless": landing_dust.burst(track.point(distance,lane),motion_reduced)
		elif event == "settle" and DisplayServer.get_name() != "headless":
			landing_dust.burst(track.point(distance,lane),true)
	var surface_events: Array[String] = []
	if not crash.active and not air.active and not was_airborne and flight_events.is_empty(): surface_events = surface.contact(track.active,old_surface_position,Vector2(lane,distance),speed,brake,impact)
	surface.update_lane(track.active,Vector2(lane,distance),speed,brake,impact,not air.active and not crash.active)
	for event in surface_events:
		if event == "boost":
			speed = maxf(speed,minf(pad_speed_cap(),speed+8))
			score += 50
			boosting = true
			boost_kick = 0.55
		elif event == "mud":
			speed *= 0.86
			if DisplayServer.get_name() != "headless" and speed > 10: landing_dust.burst(track.point(distance,lane),motion_reduced)
		elif event == "truck":
			# A parked truck is a wall: the car loses most of its speed and is thrown to the open side.
			var away := signf(lane-surface.truck_lane)
			if away == 0: away = 1.0
			lane_velocity = away*8.0
			speed *= 0.5
			traffic_hits += 1
			if bump_cooldown <= 0: register_impact(0.9,Vector2(-away,0))
		else:
			speed *= 0.96
			if DisplayServer.get_name() != "headless" and speed > 10:
				var forward := (track.point(distance+2)-track.point(distance)).normalized()
				water_effect.burst(track.point(distance,lane),forward,motion_reduced)
	# Wading through mud keeps dragging the car down while any part of it is still in the patch.
	if surface.mud_time > 0 and not air.active: speed = maxf(0,speed-delta*34)
	boosting = nitro_active or pad_active or (draft_charge > 0.65 and throttling and not drifting and impact < 0.15)
	brain.tick(self,delta)
	for i in range(rivals.size()):
		var r: Dictionary = rivals[i]
		if not r.active or r.detached != null: continue
		var gap: float = relative_gap(r.distance,distance)
		if absf(gap) > 8: continue
		var forward := (track.point(distance+2)-track.point(distance)).normalized()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var other_world := track.traffic_point(r.distance,r.lane,r.route_side)
		var relative_world := other_world-track.point(distance,lane)
		var lateral_gap := relative_world.dot(right)
		var other_forward := track.traffic_point(r.distance+2,r.lane,r.route_side)-other_world
		var other_yaw := wrapf(atan2(-other_forward.x,-other_forward.z)-track.heading(distance),-PI,PI)
		other_yaw += r.visual_yaw
		var contact: Dictionary = Contact.overlap(relative_world.dot(forward),lateral_gap,slip_angle,other_yaw) if absf(relative_world.y+float(r.air.height)-air.height) <= 1.65 else {}
		if old_gaps[i] > 0 and gap <= 0:
			overtakes += 1
			overtake_flash = 1
			score += 100
			if contact.is_empty() and absf(lateral_gap) < 3.8 and absf(relative_world.y+float(r.air.height)-air.height) < 1.5:
				near_misses += 1
				near_miss_flash = 1.1
				nitro = minf(100,nitro+6)
				score += 150
		if not contact.is_empty(): resolve_contact(r,contact)
	if drifting and offroad_amount < 0.15 and margin > 1 and impact < 0.1:
		score += delta * speed * (2.0+drift_charge)
	recommended_speed = vehicle.max_speed
	for look in [15.0,45.0,85.0]:
		var k: float = absf(track.curvature(distance+look))
		recommended_speed = minf(recommended_speed,sqrt((vehicle.grip+track.active.banking_grip(distance+look))*surface.grip_factor*1.25/maxf(k,0.0001)))
	corner_warning = move_toward(corner_warning,clampf((speed-recommended_speed-4)/15,0,1),delta*3)
	hazard_text = Features.hazard_ahead(track.active,distance) if mode == "tour" else ""
	if mode == "track":
		var finished_laps := int(maxf(0,distance-80)/track.length)
		if finished_laps > laps_completed:
			laps_completed = finished_laps
			last_lap = elapsed-lap_started
			lap_started = elapsed
			checkpoint_flash = 2
			nitro = minf(100,nitro+15)
			nitro_charges = mini(vehicle.charges,nitro_charges+1)
			if laps_completed >= 3: finish()
	else:
		if stage_index < Library.STAGES-1 and old_surface_position.y < track.active.checkpoint_distance() and distance >= track.active.checkpoint_distance(): award_checkpoint()
		var reconsidered := track.reconsider(distance,lane)
		if not reconsidered.is_empty():
			var old_section = track.sibling
			distance = reconsidered.distance
			lane = reconsidered.lane
			for r in rivals:
				if r.detached == track.active: r.detached = null
				elif r.detached == null and r.distance > 0: r.detached = old_section
			route_confirm_title = Library.title(stage_index,route_node)
			brain.stage_changed(self)
		track.maintain(distance)
		if stage_index == Library.STAGES-1 and distance >= track.length:
			finish()
		elif stage_index < Library.STAGES-1 and distance >= track.length+Library.FORK_COMMIT:
			advance_route()
		if time_left <= 0 and state != "finished":
			state = "failed"
			cancel_nitro()
			drifting = false
			boosting = false

func pad_speed_cap() -> float:
	return maxf(vehicle.overdrive_speed+2,vehicle.max_speed+21)

func update_recovery(delta: float) -> void:
	var at: Vector3 = world_race.player_body.feet_position() if world_race != null else track.point(distance,lane)+Vector3.UP*air.height
	recovery.advance(delta,at)
	if world_race == null and not crash.active and not air.active and impact < 0.1 and absf(lane) < track.half_width(distance)-1:
		recovery_distance = distance
		recovery_lane = lane

func apply_crash_pose() -> void:
	# Rotate about the chassis centre, so a barrel roll cannot orbit the road
	# contact point or bury the model beneath the visible road on touchdown.
	var pivot := Vector3(0,0.7,0)
	player.body.rotation = Vector3(crash.visual_pitch,0,crash.visual_roll)
	player.body.position = Vector3(0,player.ride_offset,0)+pivot-player.body.basis*pivot

# Back on the road after leaving it past the guardrail; no button, no waiting.
func return_to_road() -> void:
	if world_race == null or state != "racing": return
	world_race.rescue_player()
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0,player.ride_offset,0)
	speed = 0
	lane_velocity = 0
	steer = 0
	slip_angle = 0
	wall_assist = 0
	offroad_amount = 0
	impact = 0
	impact_age = 1
	drifting = false
	drift_latched = false
	drift_charge = 0
	return_flash = 1.6

func recover_car() -> void:
	if not recovery_available: return
	var used_ramps: Dictionary = air.consumed.duplicate()
	var launches: int = air.launches
	var landings: int = air.landings
	if world_race != null:
		if not world_race.recover_player(): return
	else:
		var found := false
		for back in [0.0,8.0,16.0,24.0]:
			var d := maxf(0,minf(distance,recovery_distance)-back)
			for candidate in [0.0,-3.2,3.2,-5.5,5.5]:
				var clear := true
				for rival in rivals:
					if rival.active and rival.detached == null and absf(relative_gap(rival.distance,d)) < 7 and absf(rival.lane-candidate) < 2.6: clear = false; break
				if clear and absf(candidate) < track.half_width(d)-1:
					distance = d
					lane = candidate
					found = true
					break
			if found: break
		if not found: return
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0,player.ride_offset,0)
	speed = 0
	lane_velocity = 0
	steer = 0
	slip_angle = 0
	wall_assist = 0
	air.reset()
	air.consumed = used_ramps
	air.launches = launches
	air.landings = landings
	offroad_amount = 0
	impact = 0
	impact_age = 1
	drifting = false
	drift_latched = false
	drift_charge = 0
	drift_pending = 0
	cancel_nitro()
	tire_trails.reset()
	place_cars()
	update_camera(1)
	player.reset_physics_interpolation()
	camera.reset_physics_interpolation()

func route_choices_visible() -> bool:
	return mode == "tour" and state == "racing" and stage_index < Library.STAGES-1 and checkpoint_stage == stage_index

func select_route(side: int) -> void:
	if not route_choices_visible(): return
	route_preference = clampi(side,0,1)
	route_choice_flash = 0.4
	if screen_transition != null and sound_enabled: screen_transition.ui_sound.play()

func route_axis(manual: float) -> float:
	if route_preference < 0 or not route_choices_visible() or distance < track.length-170: return manual
	# Real steering always wins; a selected route provides optional lane assistance.
	if absf(manual) > 0.2:
		route_preference = -1
		return manual
	var target := -3.5 if route_preference == 0 else 3.5
	if distance > track.length and track.previews.size() == 2:
		var f: Vector3 = (track.point(distance+2)-track.point(distance)).normalized()
		var right := Vector3(-f.z,0,f.x).normalized()
		target += (track.previews[route_preference].point(distance-track.length)-track.point(distance)).dot(right)
	return clampf((target-lane)*0.3,-0.85,0.85)

func award_checkpoint() -> void:
	if checkpoint_stage == stage_index: return
	checkpoint_stage = stage_index
	checkpoints += 1
	checkpoint_flash = 2
	checkpoint_award = Library.checkpoint_bonus(route_node)
	time_left += checkpoint_award
	nitro = minf(100,nitro+15)
	nitro_charges = mini(vehicle.charges,nitro_charges+1)

func advance_route() -> void:
	recovery.reset()
	recovery_distance = 5
	recovery_lane = 0
	var choice := 0 if lane < 0 else 1
	var result := track.advance(choice,distance,lane)
	completed_distance += result.old_length
	distance = result.distance
	lane = result.lane
	for r in rivals:
		if r.detached != null: continue
		r.distance -= result.old_length
		if r.distance > 20 and r.route_side != choice: r.detached = result.sibling
	route_preference = -1
	route_confirm_flash = 1.4
	route_confirm_title = Library.title(stage_index,route_node)
	brain.stage_changed(self)

func finish() -> void:
	state = "finished"
	cancel_nitro()
	drifting = false
	boosting = false
	if mode == "tour": score += int(time_left)*100
	previous_best = best_time
	new_record = best_time == 0 or elapsed < best_time
	if new_record:
		best_time = elapsed
		if save_records:
			var saved := ConfigFile.new()
			saved.load("user://records.cfg")
			saved.set_value(RECORD_GROUP,Catalog.record_key(selected_vehicle,mode,selected_course),best_time)
			saved.save("user://records.cfg")

func contact_with(r: Dictionary) -> Dictionary:
	var own: Vector3 = track.point(distance,lane)
	var other: Vector3 = track.traffic_point(r.distance,r.lane,r.route_side)
	if absf(other.y+float(r.air.height)-own.y-air.height) > 1.65: return {}
	var forward := track.point(distance+2,lane)-track.point(distance-2,lane)
	forward.y = 0
	forward = forward.normalized()
	var right := Vector3(-forward.z,0,forward.x).normalized()
	var delta := other-own
	var direction := track.traffic_point(r.distance+2,r.lane,r.route_side)-track.traffic_point(r.distance-2,r.lane,r.route_side)
	var yaw := wrapf(atan2(-direction.x,-direction.z)-atan2(-forward.x,-forward.z),-PI,PI)+float(r.visual_yaw)
	return Contact.overlap(delta.dot(forward),delta.dot(right),slip_angle,yaw)

func resolve_contact(r: Dictionary, contact: Dictionary) -> void:
	var normal: Vector2 = contact.normal
	for iteration in range(5):
		var depth: float = contact.depth + 0.02
		var n: Vector2 = contact.normal
		var old_lane := lane
		var radius := Contact.HALF_WIDTH*absf(cos(slip_angle))+Contact.HALF_LENGTH*absf(sin(slip_angle))
		var limits := track.lane_limits(distance)+Vector2(radius-Contact.HALF_WIDTH,-radius+Contact.HALF_WIDTH)
		lane = clampf(lane-n.x*depth*0.6,limits.x,limits.y)
		distance += n.y*depth*0.6
		var traffic_edge: float = track.half_width(r.distance)
		r.lane = clampf(r.lane+n.x*depth+(lane-old_lane),-traffic_edge,traffic_edge)
		r.distance -= n.y*depth*0.4
		contact = contact_with(r)
		if contact.is_empty(): break
	if bump_cooldown > 0: return
	var relative := speed-float(r.speed)
	var contact_speed := maxf(absf(relative),absf(lane_velocity)*2.5)
	if absf(normal.x) > 0.65: contact_speed = maxf(contact_speed,speed*0.18)
	if absf(normal.x) > 0.65:
		speed *= 0.87
		r.speed *= 0.91
		lane_velocity = -normal.x*clampf(absf(lane_velocity)*0.42+absf(relative)*0.12,2,10)
	else:
		if normal.y < 0:
			var impulse := maxf(0,relative)*0.64
			speed = maxf(0,speed-impulse)
			r.speed += impulse
		else:
			var impulse := maxf(0,-relative)*0.64
			speed += impulse
			r.speed = maxf(0,r.speed-impulse)
		lane_velocity -= normal.x*(3+absf(relative)*0.12)
	traffic_hits += 1
	if r.has("surface"): r.surface.cancel_boost()
	r.boosting = false
	register_impact(smoothstep(1.5,36,contact_speed),-normal)

func register_impact(strength: float, normal: Vector2, world_at: Vector3 = Vector3.INF) -> void:
	# Separation and speed loss happen at the contact site. Feedback is emitted
	# once per cooldown, and parked/gentle contacts do not create a crash burst.
	if bump_cooldown > 0: return
	strength = clampf(strength,0,1)
	if strength < 0.07: strength = 0
	impact = maxf(impact,strength)
	impact_normal = normal.normalized()
	impact_recoil = strength
	impact_age = 0
	# A freeze-frame on hard hits makes them land (skipped with reduced motion).
	if strength > 0.55 and not motion_reduced: hitstop_until = Time.get_ticks_msec()+int(50+strength*70)
	cancel_nitro()
	drifting = false
	drift_charge = 0
	drift_latched = false
	drift_pending = 0
	bump_cooldown = 0.45
	if strength > 0 and DisplayServer.get_name() != "headless":
		var f := (track.point(distance+2)-track.point(distance)).normalized()
		if world_race != null: f = world_race.player_body.forward_direction()
		var right := Vector3(-f.z,0,f.x)
		var at := track.point(distance,lane) + Vector3.UP*0.55 - right*normal.x*1.25 + f*normal.y*2.0
		if world_at.is_finite(): at = world_at
		impacts.burst(at,-right*normal.x+f*normal.y-f*0.7,motion_reduced,strength)

func place_cars(delta: float = 1.0) -> void:
	if world_race != null:
		world_race.place_cars()
		return
	var pitch := atan2(air.velocity,maxf(1,speed))*0.22 if air.active else (atan2(0.75,16) if air.height > 0 else 0.0)
	set_car_frame(player,track.point(distance,lane)+Vector3.UP*air.height,track.point(distance+2,lane)-track.point(distance-2,lane),delta,pitch,track.active.bank_at(distance))
	player.body.rotation.y = slip_angle
	for r in rivals:
		if not r.active:
			r.car.visible = false
			continue
		var p: Vector3
		var f: Vector3
		if r.detached != null and is_instance_valid(r.detached):
			p = r.detached.point(r.distance,r.lane)
			f = r.detached.point(r.distance+2,r.lane)-r.detached.point(r.distance-2,r.lane)
		else:
			p = track.traffic_point(r.distance,r.lane,r.route_side)
			f = track.traffic_point(r.distance+2,r.lane,r.route_side)-track.traffic_point(r.distance-2,r.lane,r.route_side)
		var pitch_npc: float = atan2(r.air.velocity,maxf(1,r.speed))*0.22 if r.air.active else (atan2(0.75,16) if r.air.height > 0 else 0.0)
		set_car_frame(r.car,p+Vector3.UP*r.air.height,f,delta,pitch_npc,track.active.bank_at(r.distance))
		r.car.body.rotation.y = r.visual_yaw
		var gap := p.distance_to(player.position)
		r.car.visible = gap < 460
		r.car.set_detail(gap)

func set_car_frame(car: Node3D, p: Vector3, forward: Vector3, delta: float, pitch_extra: float = 0, bank: float = 0) -> void:
	car.position = p + Vector3.UP*0.12
	var f := forward.normalized()
	car.rotation.y = lerp_angle(car.rotation.y,atan2(-f.x,-f.z),1-exp(-delta*13))
	car.rotation.z = lerp_angle(car.rotation.z,bank,1-exp(-delta*10))
	car.rotation.x = lerp_angle(car.rotation.x,asin(clampf(f.y,-1,1))+pitch_extra,1-exp(-delta*10))

func _process(_delta: float) -> void:
	render_budget.tick(self)

func collision_camera_offset(forward: Vector3, right: Vector3) -> Vector3:
	if state != "racing" or motion_reduced or impact_age > 0.42: return Vector3.ZERO
	# A quick directional compression and a single diminishing rebound rather
	# than an arbitrary shake that looks identical for left and right impacts.
	var pulse := impact_recoil*exp(-impact_age*16)*cos(impact_age*22)
	return (right*impact_normal.x*0.48-forward*impact_normal.y*0.36+Vector3.UP*0.055)*pulse*(1.0+impact_recoil*1.6)

func update_camera(delta: float) -> void:
	if world_race != null:
		world_race.update_camera(delta)
		return
	camera_intro = maxf(0,camera_intro-delta*0.8)
	var forward := (track.point(distance+3)-track.point(distance)).normalized()
	var right := Vector3(-forward.z,0,forward.x)
	var pace := clampf(speed/88,0,1)
	var active := state == "racing"
	camera_time += delta if active else 0
	var shake := (0.012*pace*pace + impact*0.10 + offroad_amount*pace*0.022) if active and not motion_reduced else 0.0
	var vibration := right*sin(camera_time*53)*shake + Vector3.UP*cos(camera_time*67)*shake*0.55
	var desired := -forward*(5.3+pace*0.25+(boost_kick*0.55 if not motion_reduced else 0.0)-(0.25 if braking else 0.0)) + Vector3.UP*((2.75 if motion_reduced else 2.60)-pace*0.30) + vibration
	if camera_intro > 0: desired += -forward*camera_intro*3.5+Vector3.UP*camera_intro*2.0
	if not motion_reduced: desired.y -= air.landing_flash*air.landing_strength*0.32
	if drifting and not motion_reduced: desired += right*steer*0.9
	camera_offset = camera_offset.lerp(desired,1-exp(-delta*9))
	var collision_offset := collision_camera_offset(forward,right)
	camera.position = player.position+camera_offset+collision_offset
	camera.look_at(player.position+forward*(2.5+pace*0.8)+right*steer*(0 if motion_reduced else 0.7)+Vector3.UP*0.7)
	if not motion_reduced: camera.rotate_object_local(Vector3.FORWARD,-steer*pace*(0.024 if drifting else 0.01)+collision_offset.dot(right)*0.035)
	var target_fov: float = (68.0 if motion_reduced else 64+pace*20.4) + (7.2 if boosting and active and not motion_reduced else 0)
	camera.fov = lerpf(camera.fov,target_fov,1-exp(-delta*(8 if boosting else 4)))

func update_atmosphere(delta: float) -> void:
	if mode == "track":
		var sheltered: bool = track.active.in_tunnel(distance)
		var blend := 1-exp(-delta*3)
		atmosphere.ambient_light_energy = lerpf(atmosphere.ambient_light_energy,0.12 if sheltered else 0.28,blend)
		rim_light.light_energy = lerpf(rim_light.light_energy,0.025 if sheltered else 0.10,blend)
		return
	var theme_id: String = track.scenery.theme
	if visual_theme != theme_id:
		visual_theme = theme_id
		atmosphere_transition = 3.0
	if atmosphere_transition <= 0: return
	var profile := {"top":Color("438cce"),"horizon":Color("cce5e9"),"fog":Color("b3d3df"),"sun":0.95,"ambient":0.35,"sun_color":Color("fff0d4")}
	match theme_id:
		"neon": profile.merge({"top":Color("101027"),"horizon":Color("383456"),"fog":Color("292a46"),"sun":0.12,"ambient":0.5,"sun_color":Color("b7c4ef")},true)
		"snow": profile.merge({"top":Color("90b9d4"),"horizon":Color("e6eff6"),"fog":Color("dbe5ec"),"sun":0.8,"ambient":0.45,"sun_color":Color("e9f0ff")},true)
		"volcano": profile.merge({"top":Color("8a655e"),"horizon":Color("bc8265"),"fog":Color("8b635a"),"sun":0.7,"ambient":0.4,"sun_color":Color("ffd2aa")},true)
		"canyon": profile.merge({"top":Color("ad927e"),"horizon":Color("f2cc8e"),"fog":Color("bfb190"),"sun":0.9},true)
		"harbor": profile.merge({"top":Color("587e97"),"horizon":Color("b6ccda"),"fog":Color("96b1c1"),"sun":0.8,"ambient":0.4},true)
		"bamboo": profile.merge({"top":Color("6d9f99"),"horizon":Color("c0d3b6"),"fog":Color("90b1a4"),"sun":0.8},true)
	var blend := 1.0 if delta >= atmosphere_transition else 1-exp(-delta*2)
	sky_colors.sky_top_color = sky_colors.sky_top_color.lerp(profile.top,blend)
	sky_colors.sky_horizon_color = sky_colors.sky_horizon_color.lerp(profile.horizon,blend)
	atmosphere.fog_light_color = atmosphere.fog_light_color.lerp(profile.fog,blend)
	atmosphere.ambient_light_energy = lerpf(atmosphere.ambient_light_energy,profile.ambient,blend)
	sun_light.light_energy = lerpf(sun_light.light_energy,profile.sun,blend)
	sun_light.light_color = sun_light.light_color.lerp(profile.sun_color,blend)
	rim_light.light_energy = lerpf(rim_light.light_energy,0.035 if theme_id == "neon" else 0.10,blend)
	atmosphere_transition = maxf(0,atmosphere_transition-delta)
