extends Node3D
const Track = preload("res://scripts/track.gd")
const Car = preload("res://scripts/car.gd")
const HUD = preload("res://scripts/hud.gd")
const Library = preload("res://scripts/route_library.gd")
const RivalState = preload("res://scripts/rival_state.gd")
const RenderResources = preload("res://scripts/render_resources.gd")
const SurfaceState = preload("res://scripts/road_surface_state.gd")
const AirState = preload("res://scripts/air_state.gd")
const Features = preload("res://scripts/road_features.gd")
const Factory = preload("res://scripts/vehicle_factory.gd")
const Circuit = preload("res://scripts/circuit_track.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const Haptics = preload("res://scripts/haptics.gd")
const Tuning = preload("res://scripts/drive_tuning.gd")
const Pad = preload("res://scripts/gamepad_input.gd")
const Nitro = preload("res://scripts/nitro_system.gd")
const RenderBudget = preload("res://scripts/render_budget.gd")
const WorldRace = preload("res://scripts/world_race.gd")
const TourRace = preload("res://scripts/tour_world_race.gd")
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
var owns_render_resources := false
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
var rendering_viewport: Viewport
var previous_disable_3d := false
var warming_world := false:
	set(value):
		warming_world = value
		sync_world_rendering()
var camera_intro := 0.0
var selected_course := 0
var world_race: Node3D
const COURSE_TITLES := ["FUJI LAKESIDE","SUNCOAST SPEEDWAY","MIDNIGHT HARBOR","AZURE RIVIERA","SCARLET GORGE"]
const COURSE_LABELS := ["FUJI / CIRCUIT 01","SUNCOAST / CIRCUIT 02","MIDNIGHT / CIRCUIT 03","RIVIERA / CIRCUIT 04","GORGE / CIRCUIT 05"]
const COURSE_COUNT := 5
var coast_drift := preload("res://scripts/coast_drift.gd").new()
var course_title: String:
	get: return COURSE_TITLES[clampi(selected_course,0,COURSE_COUNT-1)]
var course_label: String:
	get: return COURSE_LABELS[clampi(selected_course,0,COURSE_COUNT-1)]
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
		sync_world_rendering()
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
var haptics := Haptics.new()
# 0-1 while a wheel is on the kerb or the car is scraping a rail: it shakes the camera and the pad.
var edge_rumble := 0.0
# Gamepad focus on the home and course screens (0/1 the two big cards, 2 the corner button).
var menu_focus := 0
var menu_last_card := 0
var nav_dir := ""
var nav_wait := 0.0
var scrape_timer := 0.0
var gamepad_active := false
var settings_focus := 0
var preferences_path := "user://settings.cfg"
# Small frames-per-second counter in the corner during a race (Settings > SHOW FPS).
var show_fps := false
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

func _enter_tree() -> void:
	RenderResources.acquire_owner()
	owns_render_resources = true

func _ready() -> void:
	rendering_viewport = get_viewport()
	previous_disable_3d = rendering_viewport.disable_3d
	track = Track.new()
	add_child(track)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	atmosphere = env
	var sky_material := ProceduralSkyMaterial.new()
	sky_colors = sky_material
	sky_material.sky_top_color = Color("438cce")
	sky_material.sky_horizon_color = Color("cce5e9")
	sky_material.ground_bottom_color = Color("688370")
	sky_material.ground_horizon_color = Color("c3d9db")
	env.background_mode = Environment.BG_SKY
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
			haptics.phone_buzz = bool(JavaScriptBridge.eval("typeof navigator.vibrate === 'function' && /Android/i.test(navigator.userAgent)"))
		elif OS.has_feature("android"): haptics.phone_buzz = true
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
	create_world_controller()
	world_race.reset()
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
	sync_world_rendering()
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
	if owns_render_resources:
		owns_render_resources = false
		if RenderResources.release_owner():
			preload("res://scripts/advertisement_library.gd").clear_cache()
			preload("res://scripts/regional_props_3d.gd").clear_cache()
	_hide_fullscreen_control()
	if is_instance_valid(rendering_viewport): rendering_viewport.disable_3d = previous_disable_3d
	Engine.time_scale = 1.0
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").initialsjObserveOrientation(null)
		JavaScriptBridge.get_interface("window").initialsjObserveBack(null,false)
		JavaScriptBridge.get_interface("window").initialsjObserveFullscreen(null)
		web_back_callback = null
		web_fullscreen_callback = null

func competitor_count() -> int:
	return 16 if mode == "track" and selected_course == 1 else 8

func initialize_traffic() -> void:
	RivalState.initialize(rivals)
	if mode == "track":
		for r in rivals:
			r.active = r.id < competitor_count()-1
			r.distance = 95.0+int(r.id/2)*10
			r.lane = -2.0 if r.id%2 == 0 else 2.0
			r.target_lane = r.lane
			r.speed = 0.0
			r.pace = vehicle.max_speed*(0.94+r.id*0.018)
	else:
		# The Tour is a solo time attack: no CPU cars on the road.
		for r in rivals:
			r.active = false
			r.car.visible = false

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
	menu_focus = 0
	hud.fingers.clear()
	state = "courses"

# The region name plus its style, e.g. "SKYLINE DRIVE / SKYWAY CITY".
func route_banner() -> String:
	var label: String = Features.THEME_FEEL.get(Library.theme(stage_index,route_node),{}).get("label","")
	return Library.title(stage_index,route_node)+("  /  "+label if label != "" else "")

func mode_loading_title(value: String, course: int = 0) -> String:
	if value != "track": return "COAST TOUR"
	return COURSE_TITLES[clampi(course,0,COURSE_COUNT-1)]

# Opens a mode through the transition, with a loading card when the course must be rebuilt.
func navigate_to_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if not (mode == desired and (desired == "tour" or selected_course == clampi(course,0,COURSE_COUNT-1))):
		loading_title = mode_loading_title(value,course)
	navigate(func(): choose_mode(value,course))

func choose_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if mode == desired and (desired == "tour" or selected_course == clampi(course,0,COURSE_COUNT-1)):
		open_garage()
		load_record()
		return
	if world_race != null:
		world_race.shutdown()
		remove_child(world_race)
		world_race.queue_free()
		world_race = null
	mode = "track" if value == "track" else "tour"
	selected_course = clampi(course,0,COURSE_COUNT-1)
	remove_child(track)
	track.queue_free()
	# 다른 게임 씬이 없으면 이전 코스 전용 메시·대형 외벽·광고 참조를 비운다.
	if RenderResources.owners == 1:
		preload("res://scripts/advertisement_library.gd").clear_cache()
		preload("res://scripts/regional_props_3d.gd").clear_cache()
	track = Circuit.new() if mode == "track" else Track.new()
	if mode == "track": track.course_id = selected_course
	add_child(track)
	atmosphere.sky = null
	rim_light.light_color = Color.WHITE
	if mode == "track":
		if selected_course == 2:
			# Night: a dim cool moon, deep blue ambient light and dark blue haze.
			atmosphere.fog_light_color = Color("0c1a30")
			atmosphere.fog_density = 0.0016
			atmosphere.ambient_light_color = Color("5a78b8")
			atmosphere.ambient_light_energy = 0.55
			atmosphere.tonemap_exposure = 1.0
			sun_light.rotation_degrees = Vector3(-38,150,0)
			sun_light.light_energy = 0.32
			sun_light.light_color = Color("a8c0ff")
			rim_light.light_energy = 0.18
		else:
			atmosphere.fog_light_color = Color("b3d3df")
			atmosphere.fog_density = 0.00065
			atmosphere.ambient_light_color = Color("b5cce0")
			atmosphere.tonemap_exposure = 0.88
			sun_light.rotation_degrees = Vector3(-42,-32,0)
			sun_light.light_energy = 1.0
			sun_light.light_color = Color("ffe4be")
			rim_light.light_energy = 0.10
			atmosphere.ambient_light_energy = 0.28
		if selected_course in [3,4]:
			atmosphere.fog_light_color = Color("87bdcf")
			atmosphere.fog_density = 0.00022
			atmosphere.tonemap_exposure = 0.76
			sun_light.light_energy = 0.85
		if selected_course == 4:
			# 파노라마 태양 U=.65,V=.49와 같은 방위·낮은 고도의 주광을 고정한다.
			sun_light.rotation_degrees = Vector3(-5,54,0)
			sun_light.light_color = Color("ffbf82")
			sun_light.light_energy = .78
			atmosphere.ambient_light_color = Color("899ec5")
			atmosphere.ambient_light_energy = .38
			atmosphere.fog_light_color = Color("bd9fa8")
			atmosphere.fog_density = .00038
			atmosphere.tonemap_exposure = .9
			rim_light.light_color = Color("a2b6db")
			rim_light.light_energy = .14
	else:
		visual_theme = ""
	create_world_controller()
	render_budget.apply(self)
	state = "ready"
	open_garage()
	load_record()

func create_world_controller() -> void:
	world_race = WorldRace.new() if mode == "track" else TourRace.new()
	world_race.race = self
	add_child(world_race)
	world_race.setup()

func open_menu() -> void:
	menu_focus = 0
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
		show_fps = bool(config.get_value("preferences","show_fps",false))

func save_preferences() -> void:
	if not save_records: return
	var config := ConfigFile.new()
	config.set_value("preferences","sound",sound_enabled)
	config.set_value("preferences","show_fps",show_fps)
	if motion_user_set: config.set_value("preferences","reduced_motion",motion_reduced)
	config.set_value("preferences","graphics",graphics_mode)
	config.save(preferences_path)

# Every screen that offers these switches goes through here, so a choice made on
# the pause or result dialog survives a reload like one made in Settings.
func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	save_preferences()

func toggle_fps() -> void:
	show_fps = not show_fps
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

func restart(start_countdown: bool = true) -> void:
	hazard_text = ""
	if track.active.closed_loop and track.active.course_id == 3: track.scenery.rock_arches.reset_effect()
	haptics.stop()
	edge_rumble = 0
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0,player.ride_offset,0)
	recovery_distance = 80
	recovery_lane = -3.2
	if mode == "tour" and (track.active.stage != 0 or not track.history.is_empty()): track.reset()
	if track.active.collapse != null: track.active.collapse.reset_effect()
	if track.active.rockfall != null: track.active.rockfall.reset_effect()
	preload("res://scripts/advertisement_library.gd").reshuffle(get_tree())
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
	coast_drift.reset()
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
	state = "countdown" if start_countdown else "ready"
	initialize_traffic()
	if world_race != null:
		world_race.reset()
		if mode == "track" and selected_course == 1: preload("res://scripts/rolling_start.gd").begin(self)
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
			elif event.keycode == KEY_3: navigate_to_mode("track",2)
			elif event.keycode == KEY_4: navigate_to_mode("track",3)
			elif event.keycode == KEY_5: navigate_to_mode("track",4)
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
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN: pad_focus(button)
				JOY_BUTTON_A:
					match menu_focus:
						0: navigate_to_mode("tour")
						1: navigate(open_courses)
						_: navigate(open_settings)
				JOY_BUTTON_X: navigate(open_courses)
				JOY_BUTTON_Y: navigate(open_settings)
		"courses":
			match button:
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN: pad_focus(button)
				JOY_BUTTON_A:
					match menu_focus:
						0, 1, 2, 3, 4: navigate_to_mode("track",menu_focus)
						_: navigate(open_menu)
				JOY_BUTTON_X: navigate_to_mode("track",1)
				JOY_BUTTON_Y: navigate_to_mode("track",2)
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

# D-pad (or the left stick, see pad_stick_navigation) moves the gold focus frame: left/right
# between the two cards, up to the corner button, down back to the last card.
func pad_focus(button: int) -> void:
	# The home screen has two cards, the circuit screen three; the corner button comes after them.
	var cards := COURSE_COUNT if state == "courses" else 2
	match button:
		JOY_BUTTON_DPAD_LEFT:
			if menu_focus > 0 and menu_focus < cards: menu_focus -= 1
		JOY_BUTTON_DPAD_RIGHT:
			if menu_focus < cards-1: menu_focus += 1
		JOY_BUTTON_DPAD_UP:
			if menu_focus != cards:
				menu_last_card = menu_focus
				menu_focus = cards
		JOY_BUTTON_DPAD_DOWN:
			if menu_focus == cards: menu_focus = menu_last_card

# The left stick drives every menu like the D-pad, with a short repeat while held.
func pad_stick_navigation(delta: float) -> void:
	if state not in ["menu","courses","settings","ready"] or (screen_transition != null and screen_transition.busy):
		nav_dir = ""
		return
	var x := pad.axis(JOY_AXIS_LEFT_X)
	var y := pad.axis(JOY_AXIS_LEFT_Y)
	var wanted := ""
	if absf(x) > 0.6 and absf(x) >= absf(y): wanted = "right" if x > 0 else "left"
	elif absf(y) > 0.6: wanted = "down" if y > 0 else "up"
	if wanted == "":
		nav_dir = ""
		nav_wait = 0
		return
	nav_wait -= delta
	if wanted == nav_dir and nav_wait > 0: return
	var first: bool = wanted != nav_dir
	nav_dir = wanted
	nav_wait = 0.4 if first else 0.17
	gamepad_active = true
	pad_pressed({"left":JOY_BUTTON_DPAD_LEFT,"right":JOY_BUTTON_DPAD_RIGHT,"up":JOY_BUTTON_DPAD_UP,"down":JOY_BUTTON_DPAD_DOWN}[wanted])

const SETTINGS_ROWS := 7
func settings_activate(index: int) -> void:
	match index:
		0: toggle_sound()
		1: toggle_motion()
		2: cycle_graphics()
		3: toggle_fps()
		4: toggle_fullscreen()
		5: hud.install_game()
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
		haptics.stop()
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
	if mode == "track" and selected_course == 1: track.active.speedway_board.bind(self)

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
	restart(false)
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
		if mode == "track" and selected_course == 1: preload("res://scripts/rolling_start.gd").advance(self,minf(delta,countdown))
		countdown -= delta
		if countdown <= 0:
			if mode == "track" and selected_course == 1: preload("res://scripts/rolling_start.gd").release(self)
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
	sync_world_rendering()
	var world_visible := not rendering_viewport.disable_3d
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
	var night: bool = track.scenery.theme in ["neon","night"]
	player.set_headlights(track.active.in_tunnel(distance) or night)
	for r in rivals:
		r.car.set_headlights(r.active and (night or track.active.in_tunnel(r.distance)),false)
		if not r.active or not r.car.visible or absf(relative_gap(r.distance,distance)) > 145:
			if r.get("visual_running",true): r.car.animate(0,false,false,0)
			r.visual_running = false
			continue
		r.visual_running = true
		r.car.road_speed = r.speed if state == "racing" else 0.0
		r.car.animate(clampf((r.target_lane-r.lane)/2,-1,1),r.active and r.drifting and r.car.visible and absf(relative_gap(r.distance,distance)) < 80 and state == "racing",r.boosting and state == "racing",delta,0)
	# HUD._process owns its redraw; physics ticks need not enqueue it again.

func sync_world_rendering() -> void:
	if not is_instance_valid(rendering_viewport) or not is_instance_valid(player): return
	var world_visible := warming_world or state not in ["menu","courses","ready","settings"]
	# GLES3는 첫 렌더 전 교체된 Sky의 대기 중 큐브맵을 남길 수 있다.
	# 가려진 코스 선택에서는 만들지 않고 실제 렌더·프리워밍 때 생성한다.
	if world_visible and atmosphere.sky == null:
		if mode == "track": atmosphere.sky = track.scenery.make_sky()
		else:
			var sky := Sky.new()
			sky.sky_material = sky_colors
			sky.radiance_size = Sky.RADIANCE_SIZE_128
			atmosphere.sky = sky
	rendering_viewport.disable_3d = not world_visible
	if is_instance_valid(track):
		track.visible = world_visible
		# Pause decorative animation without removing road collision bodies from
		# the physics space (PROCESS_MODE_DISABLED would also disable colliders).
		if track.scenery.has_method("_process"): track.scenery.set_process(world_visible)
	player.visible = world_visible
	tire_trails.visible = world_visible
	if not world_visible:
		for r in rivals: r.car.visible = false

func step(delta: float, axis: float, drift_input: bool, gas: bool, brake: bool, nitro_input: bool = false, cell_input: bool = false) -> void:
	edge_rumble = move_toward(edge_rumble,0,delta*4)
	haptics.enabled = not motion_reduced
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
	hazard_text = ""
	world_race.step(delta,axis,drift_input,gas,brake,nitro_input,cell_input)
	if track.active.collapse != null:
		track.active.collapse.advance(delta,distance,motion_reduced)
		hazard_text = track.active.collapse.warning(distance)
	if track.active.rockfall != null:
		track.active.rockfall.advance(delta,distance,laps_completed)
		var rock_warning: String = track.active.rockfall.warning(distance)
		if not rock_warning.is_empty(): hazard_text = rock_warning

	if track.active.closed_loop and track.active.course_id == 3:
		hazard_text = preload("res://scripts/riviera_profile.gd").warning(fposmod(distance,track.length))
		track.scenery.rock_arches.advance(delta,distance,laps_completed)
		var arch_warning: String = track.scenery.rock_arches.warning(distance)
		if not arch_warning.is_empty(): hazard_text = arch_warning

func pad_speed_cap() -> float:
	return maxf(vehicle.overdrive_speed+2,vehicle.max_speed+21)

func update_recovery(delta: float) -> void:
	recovery.advance(delta,world_race.player_body.feet_position())

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
	var launches: int = air.launches
	var landings: int = air.landings
	if not world_race.recover_player(): return
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
	route_preference = -1
	route_confirm_flash = 1.4
	route_confirm_title = route_banner()
	for rival in rivals: rival.active = false

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
	if mode == "track" and selected_course == 1:
		track.active.speedway_board.add_result(elapsed,str(vehicle.name),save_records)

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
	if strength > 0: haptics.pulse(0.35+0.65*strength,0.5+0.5*strength,0.1+0.3*strength,3)
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

# Called every frame the car grinds along a rail: rumble, camera shake and a stream of sparks.
func scrape(delta: float, outward: Vector3, at: Vector3) -> void:
	edge_rumble = 1.0
	haptics.pulse(0.25,0.6,0.08,1)
	scrape_timer -= delta
	if scrape_timer > 0 or impact_age < 0.5: return
	scrape_timer = 0.14 if motion_reduced else 0.07
	if DisplayServer.get_name() == "headless": return
	var f := (track.point(distance+2)-track.point(distance)).normalized()
	if world_race != null: f = world_race.player_body.forward_direction()
	impacts.burst(at,-f*0.9-outward*0.25,motion_reduced,0.3)

func place_cars(_delta: float = 1.0) -> void:
	world_race.place_cars()

func _process(delta: float) -> void:
	render_budget.tick(self)
	pad_stick_navigation(delta)

func collision_camera_offset(forward: Vector3, right: Vector3) -> Vector3:
	if state != "racing" or motion_reduced or impact_age > 0.42: return Vector3.ZERO
	# A quick directional compression and a single diminishing rebound rather
	# than an arbitrary shake that looks identical for left and right impacts.
	var pulse := impact_recoil*exp(-impact_age*16)*cos(impact_age*22)
	return (right*impact_normal.x*0.48-forward*impact_normal.y*0.36+Vector3.UP*0.055)*pulse*(1.0+impact_recoil*1.6)

func update_camera(delta: float) -> void:
	world_race.update_camera(delta)

func update_atmosphere(delta: float) -> void:
	if mode == "track" and selected_course == 2:
		# The moon stays low in the sky ahead and slightly to the left, whichever way the road turns.
		var look: Vector3 = -camera.global_transform.basis.z
		look.y = 0
		if look.length_squared() > 0.01 and atmosphere.sky != null and atmosphere.sky.sky_material is ShaderMaterial:
			var heading := look.normalized().rotated(Vector3.UP,deg_to_rad(24))
			(atmosphere.sky.sky_material as ShaderMaterial).set_shader_parameter("moon_direction",Vector3(heading.x,0.115,heading.z))
		return
	if mode == "track" and selected_course == 4: return
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
