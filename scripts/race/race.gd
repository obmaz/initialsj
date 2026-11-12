extends Node3D
const RaceState = preload("res://scripts/race/race_state.gd")
const Track = preload("res://scripts/track/track.gd")
const Car = preload("res://scripts/vehicles/car.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const Library = preload("res://scripts/track/route_library.gd")
const RivalState = preload("res://scripts/race/rival_state.gd")
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const SurfaceState = preload("res://scripts/track/road_surface_state.gd")
const AirState = preload("res://scripts/physics/air_state.gd")
const Features = preload("res://scripts/track/road_features.gd")
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Circuit = preload("res://scripts/track/circuit_track.gd")
const TourChallenge = preload("res://scripts/race/tour_challenge.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Haptics = preload("res://scripts/input/haptics.gd")
const Pad = preload("res://scripts/input/gamepad_input.gd")
const RenderBudget = preload("res://scripts/rendering/render_budget.gd")
const WorldRace = preload("res://scripts/race/world_race.gd")
const TourRace = preload("res://scripts/race/tour_world_race.gd")
const Crash = preload("res://scripts/physics/crash_state.gd")
const Recovery = preload("res://scripts/race/recovery_state.gd")
var crash := Crash.new()
var recovery := Recovery.new()
var passport := preload("res://scripts/race/tour_passport.gd").new()
var passport_open := false
var route_challenges := preload("res://scripts/race/route_challenges.gd").new()
var personal_run := preload("res://scripts/race/personal_run.gd").new()
var ghost: Node3D
var show_ghost := true
var max_drift_multiplier := 1
var rewards := preload("res://scripts/race/driving_rewards.gd").new()
var sound_state := preload("res://scripts/audio/vehicle_sound_state.gd").new()
var proximity_audio := preload("res://scripts/audio/proximity_audio_state.gd").new()
var slipstream := preload("res://scripts/race/slipstream_state.gd").new()
var acoustics := preload("res://scripts/audio/environment_audio_state.gd").new()
var protection_left := 0.0
var auto_accelerate := true
var recovery_distance := 80.0
var recovery_lane := -3.2
var recovery_available: bool:
	get:
		return state == RaceState.RACING and recovery.available
const GAME_PACE := 1.2
const RECORD_GROUP := "coast_rush_v3"
var selected_vehicle := 0
var vehicle: Dictionary = Catalog.spec(0)
var previews: Node
var customization := preload("res://scripts/vehicles/customization_store.gd").new()
var tuning_shop: CanvasLayer
var resume_state := RaceState.RACING
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
var tour_weather: Node
var goal_background: Node
var sky_colors: ProceduralSkyMaterial
var rim_light: DirectionalLight3D
var sun_light: DirectionalLight3D
var visual_theme := "hawaii"
var atmosphere_transition := 0.0
var camera: Camera3D
var hud: HUD
var ground_contact_material: ShaderMaterial
var rain_lens := preload("res://scripts/effects/rain_lens.gd").new()
var speed_effect: ColorRect
var tire_trails: Node3D
var speed_ambience: Node3D
var impacts: Node3D
var rivals: Array[RivalState] = []
var surface := SurfaceState.new()
var air := AirState.new()
var shoulder_dust: Node3D
var offroad_amount := 0.0
var shoulder_dust_clock := 0.0
var landing_dust: Node3D
var water_effect: Node3D
var pad_active: bool:
	get:
		return (
			state == RaceState.RACING
			and not crash.active
			and (surface.pad_time > 0 or surface.lane_active)
			and not braking
			and impact < 0.15
		)
var mode := "tour"
var graphics_mode := 0
var track_environment := preload("res://scripts/environment/track_environment.gd").new()
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
const COURSE_TITLES := ["FUJI LAKESIDE", "SUNCOAST SPEEDWAY", "MIDNIGHT HARBOR", "AZURE RIVIERA", "SCARLET GORGE"]
const COURSE_LABELS := [
	"FUJI / CIRCUIT 01", "SUNCOAST / CIRCUIT 02", "MIDNIGHT / CIRCUIT 03", "RIVIERA / CIRCUIT 04", "GORGE / CIRCUIT 05"
]
const COURSE_COUNT := 5
var coast_drift := preload("res://scripts/race/coast_drift.gd").new()
var course_title: String:
	get:
		return COURSE_TITLES[clampi(selected_course, 0, COURSE_COUNT - 1)]
var course_label: String:
	get:
		return COURSE_LABELS[clampi(selected_course, 0, COURSE_COUNT - 1)]
var settings_return := RaceState.MENU
# Shown on the loading card of the next screen transition (empty for an ordinary fade).
var loading_title := ""
# Low-memory rendering for consoles and browsers that already lost their GPU context.
var lite_graphics := false
# Short warning for the next gimmick on a Tour road (truck, steep drop, narrow road).
var hazard_text := ""
var laps_completed := 0
var lap_started := 0.0
var last_lap := 0.0
var state := RaceState.MENU:
	set(value):
		# 오타로 생긴 상태는 모든 비교에서 조용히 빠진다. 선언된 값만 받는다.
		if value not in RaceState.ALL:
			push_error("Unknown race state: " + str(value))
			return
		state = value
		if state != RaceState.MENU:
			passport_open = false
		shell.sync_back()
		if state != RaceState.SETTINGS:
			shell.hide_control()
		sync_world_rendering()
var distance := 80.0
var completed_distance := 0.0
var lane := -3.2
var speed := 0.0
var lane_velocity := 0.0
var steer := 0.0
var slip_angle := 0.0
var wall_assist := 0.0
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
var shell := preload("res://scripts/platform/web_shell.gd").new(self)
var lighting := preload("res://scripts/rendering/race_lighting.gd").new(self)
var controls := preload("res://scripts/input/race_input.gd").new(self)
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
var loaded_record_key := ""
var record_store := ConfigFile.new()
var record_cache_loaded := false
var run_medal := 0
var tour_score_multiplier := 1.0
# 투어와 TRACK04·05의 해안 드리프트 규칙: 쉬운 드리프트 진입·유지와 드리프트 점수를 쓴다.
var coast_handling: bool:
	get:
		return mode == "tour" or selected_course in [3, 4]
var stage_index: int:
	get:
		return track.active.stage
var route_node: int:
	get:
		return track.active.route_node


func _enter_tree() -> void:
	RenderResources.acquire_owner()
	owns_render_resources = true


func _ready() -> void:
	add_to_group("tour_traffic_clock")
	rendering_viewport = get_viewport()
	previous_disable_3d = rendering_viewport.disable_3d
	track = Track.new()
	add_child(track)
	lighting.setup()
	tire_trails = preload("res://scripts/effects/tire_trails.gd").new()
	add_child(tire_trails)
	speed_ambience = preload("res://scripts/effects/speed_ambience.gd").new()
	add_child(speed_ambience)
	water_effect = preload("res://scripts/effects/water_splash.gd").new()
	add_child(water_effect)
	landing_dust = preload("res://scripts/effects/landing_dust.gd").new()
	add_child(landing_dust)
	shoulder_dust = preload("res://scripts/effects/landing_dust.gd").new()
	add_child(shoulder_dust)
	impacts = preload("res://scripts/effects/impact_effect.gd").new()
	add_child(impacts)
	player = Factory.create(selected_vehicle)
	add_child(player)
	var colors := ["e7c456", "91aabe", "aaa3b7", "e8e5dc", "4c9c97", "ad6f55", "62798c"]
	for i in range(16):
		var car := Factory.create(i % Catalog.SPECS.size())
		car.traffic = true
		car.paint = Color(colors[i % colors.size()])
		add_child(car)
		rivals.append(RivalState.new(car))
	initialize_traffic()
	camera = Camera3D.new()
	camera.far = 1800
	camera.fov = 68
	add_child(camera)
	camera.current = true
	ghost = preload("res://scripts/effects/personal_ghost.gd").new()
	add_child(ghost)
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
		screen_transition = preload("res://scripts/ui/loading/screen_transition.gd").new()
		screen_transition.race = self
		add_child(screen_transition)
	if DisplayServer.get_name() != "headless":
		if OS.has_feature("web"):
			lite_graphics = bool(
				JavaScriptBridge.eval("window.initialsjLiteGraphics ? window.initialsjLiteGraphics() : false")
			)
			haptics.phone_buzz = bool(
				JavaScriptBridge.eval("typeof navigator.vibrate === 'function' && /Android/i.test(navigator.userAgent)")
			)
		elif OS.has_feature("android"):
			haptics.phone_buzz = true
		previews = preload("res://scripts/ui/garage_previews.gd").new()
		previews.lite = lite_graphics
		add_child(previews)
		for index in range(Catalog.SPECS.size()):
			previews.show_vehicle(index)
		var audio = preload("res://scripts/audio/racing_audio.gd").new()
		audio.race = self
		add_child(audio)
		if OS.has_feature("web"):
			motion_reduced = bool(
				JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches")
			)
	load_preferences()
	passport.load_progress()
	customization.load_config()
	apply_cosmetics()
	if previews != null:
		for index in range(Catalog.SPECS.size()):
			previews.customize(index, passport, customization)
	render_budget.set_mode(graphics_mode, self)
	load_record()
	reset_nitro()
	create_world_controller()
	world_race.reset()
	place_cars()
	update_camera(1)
	personal_run.prepare(self)
	ghost.prepare(self)
	shell.attach()
	if OS.has_feature("android"):
		get_tree().quit_on_go_back = false
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	sync_world_rendering()
	if OS.has_feature("web"):
		_announce_ready()


# The page keeps its loading screen until the first menu frames are drawn.
func _announce_ready() -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("window.initialsjGameReady && window.initialsjGameReady()")


# Keep hardware/browser Back consistent with the visible screen's back action.
# Repeated Back during a transition is consumed rather than queued.
func navigate_back() -> bool:
	if Time.get_ticks_msec() < shell.back_ignored_until:
		return true
	if screen_transition != null and screen_transition.busy:
		return true
	if is_instance_valid(tuning_shop):
		tuning_shop.request_close()
		return true
	if passport_open:
		toggle_passport()
		return true
	match state:
		RaceState.RACING, RaceState.COUNTDOWN:
			pause_tour()
		RaceState.PAUSED:
			resume_tour()
		RaceState.READY:
			navigate(open_courses if mode == "track" else open_menu)
		RaceState.COURSES:
			navigate(open_menu)
		RaceState.SETTINGS:
			navigate(close_settings)
		RaceState.FINISHED, RaceState.FAILED:
			leave_results()
		_:
			return false
	return true


func _exit_tree() -> void:
	if owns_render_resources:
		owns_render_resources = false
		if RenderResources.release_owner():
			preload("res://scripts/environment/advertisement_library.gd").clear_cache()
			preload("res://scripts/environment/regional_props_3d.gd").clear_cache()
			preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
	shell.detach()
	if is_instance_valid(rendering_viewport):
		rendering_viewport.disable_3d = previous_disable_3d
	Engine.time_scale = 1.0


func competitor_count() -> int:
	return 16 if mode == "track" and selected_course == 1 else 8


func initialize_traffic() -> void:
	for i in range(rivals.size()):
		rivals[i].reset(i)
	if mode == "track":
		for r in rivals:
			r.active = r.id < competitor_count() - 1
			r.distance = 95.0 + int(r.id / 2) * 10
			r.lane = -2.0 if r.id % 2 == 0 else 2.0
			r.target_lane = r.lane
			r.speed = 0.0
			r.pace = float(r.specification.max_speed) * float(r.style.pace) * (0.96 + (r.id % 3) * 0.015)
	else:
		# The Tour is a solo time attack: no CPU cars on the road.
		for r in rivals:
			r.active = false
			r.car.visible = false


func navigate(action: Callable) -> void:
	shell.hide_control()
	if screen_transition == null:
		loading_title = ""
		action.call()
	else:
		shell.hold_back()
		await screen_transition.play(action)
		shell.sync_back()


func start_race() -> void:
	navigate(
		func():
			restart()
			camera_intro = 0.0 if motion_reduced else 1.0
			if camera_intro > 0:
				var f := (track.point(distance + 3) - track.point(distance)).normalized()
				camera_offset += -f * 3.5 + Vector3.UP * 2.0
				camera.position = player.position + camera_offset
				camera.reset_physics_interpolation()
	)


func cycle_graphics() -> void:
	graphics_mode = (graphics_mode + 1) % 3
	render_budget.set_mode(graphics_mode, self)


func result_button_label() -> String:
	return "SELECT TRACK" if mode == "track" else "SELECT MODE"


func leave_results() -> void:
	if state in RaceState.ENDED:
		navigate(open_courses if mode == "track" else open_menu)


func open_courses() -> void:
	menu_focus = 0
	hud.fingers.clear()
	state = RaceState.COURSES


# The region name plus its style, e.g. "SKYLINE DRIVE / SKYWAY CITY".
func route_banner() -> String:
	var label: String = Features.THEME_FEEL.get(Library.theme(stage_index, route_node), {}).get("label", "")
	return Library.title(stage_index, route_node) + ("  /  " + label if label != "" else "")


func mode_loading_title(value: String, course: int = 0) -> String:
	if value != "track":
		return "COAST TOUR"
	return COURSE_TITLES[clampi(course, 0, COURSE_COUNT - 1)]


# Opens a mode through the transition, with a loading card when the course must be rebuilt.
func navigate_to_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if not (mode == desired and (desired == "tour" or selected_course == clampi(course, 0, COURSE_COUNT - 1))):
		loading_title = mode_loading_title(value, course)
	navigate(func(): choose_mode(value, course))


func choose_mode(value: String, course: int = 0) -> void:
	var desired := "track" if value == "track" else "tour"
	if mode == desired and (desired == "tour" or selected_course == clampi(course, 0, COURSE_COUNT - 1)):
		open_garage()
		load_record()
		return
	if world_race != null:
		world_race.shutdown()
		remove_child(world_race)
		world_race.queue_free()
		world_race = null
	mode = "track" if value == "track" else "tour"
	selected_course = clampi(course, 0, COURSE_COUNT - 1)
	remove_child(track)
	# 새 코스를 만들기 전에 바로 해제해 두 코스의 메시가 같은 프레임에 함께 남지 않게 한다.
	track.free()
	# 다른 게임 씬이 없으면 이전 코스 전용 메시·대형 외벽·광고 참조를 비운다.
	if RenderResources.owners == 1:
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
		preload("res://scripts/environment/regional_props_3d.gd").clear_cache()
		preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
	track = Circuit.new() if mode == "track" else Track.new()
	if mode == "track":
		track.course_id = selected_course
	add_child(track)
	lighting.apply_course()
	create_world_controller()
	render_budget.apply(self)
	state = RaceState.READY
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
	state = RaceState.MENU


func open_settings() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.initialsjPrepareInstall && window.initialsjPrepareInstall()")
	settings_return = state
	hud.fingers.clear()
	state = RaceState.SETTINGS


func close_settings() -> void:
	state = settings_return
	save_preferences()


func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) == OK:
		sound_enabled = bool(config.get_value("preferences", "sound", true))
		# Only a stored choice overrides the system reduced-motion preference.
		if config.has_section_key("preferences", "reduced_motion"):
			motion_reduced = bool(config.get_value("preferences", "reduced_motion"))
			motion_user_set = true
		graphics_mode = clampi(int(config.get_value("preferences", "graphics", 0)), 0, 2)
		show_fps = bool(config.get_value("preferences", "show_fps", false))
		auto_accelerate = bool(config.get_value("preferences", "auto_accelerate", true))
		show_ghost = bool(config.get_value("preferences", "show_ghost", true))
		track_environment.read(config)


func save_preferences() -> void:
	if not save_records:
		return
	var config := ConfigFile.new()
	config.set_value("preferences", "show_ghost", show_ghost)
	config.set_value("preferences", "auto_accelerate", auto_accelerate)
	config.set_value("preferences", "sound", sound_enabled)
	config.set_value("preferences", "show_fps", show_fps)
	if motion_user_set:
		config.set_value("preferences", "reduced_motion", motion_reduced)
	config.set_value("preferences", "graphics", graphics_mode)
	track_environment.write(config)
	config.save(preferences_path)


# Every screen that offers these switches goes through here, so a choice made on
# the pause or result dialog survives a reload like one made in Settings.
func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	save_preferences()


func toggle_auto_accelerate() -> void:
	auto_accelerate = not auto_accelerate
	hud.fingers.clear()
	save_preferences()


func toggle_passport() -> void:
	if state != RaceState.MENU:
		return
	passport_open = not passport_open
	hud.fingers.clear()
	shell.sync_back()


func cycle_cosmetic(plate: bool = false) -> void:
	if state != RaceState.READY:
		return
	var choices: Array = passport.unlocked_plates() if plate else passport.unlocked_paints()
	var current := customization.selection(selected_vehicle, passport)
	if choices.size() <= 1 and (plate or current.paint == Color(vehicle.paint).to_html(false)):
		hud.show_garage_notice(
			"FINISH A TOUR TO UNLOCK PLATES" if plate else "TOUR COLORS: REACH A DESTINATION / CUSTOM COLORS: TUNING"
		)
		return
	var previous := passport.paints.duplicate()
	passport.cycle(selected_vehicle, plate)
	var id: String = Catalog.spec(selected_vehicle).id
	if not plate and customization.selections.has(id):
		var data := customization.selection(selected_vehicle, passport)
		var color: String = passport.PAINTS[passport.paint_index(selected_vehicle)].color
		data.paint = Color(Catalog.spec(selected_vehicle).paint if color.is_empty() else color).to_html(false)
		if save_records:
			if customization.save(selected_vehicle, data) != OK:
				passport.paints = previous
				hud.show_garage_notice("COULD NOT SAVE THE PAINT. PLEASE TRY AGAIN.")
				return
		else:
			customization.selections[id] = data
	apply_cosmetics()
	if save_records:
		passport.save_progress()
	hud.show_garage_notice("NUMBER PLATE APPLIED" if plate else "PAINT APPLIED")


func apply_cosmetics() -> void:
	customization.apply(player, selected_vehicle, passport)
	if previews != null:
		previews.customize(selected_vehicle, passport, customization)


func open_tuning() -> void:
	if state != RaceState.READY or is_instance_valid(tuning_shop):
		return
	loading_title = "COAST CUSTOMS"
	navigate(
		func():
			tuning_shop = preload("res://scripts/ui/tuning/tuning_shop.gd").new()
			tuning_shop.race = self
			tuning_shop.vehicle_index = selected_vehicle
			tuning_shop.saved_customization = customization.selection(selected_vehicle, passport)
			tuning_shop.draft_customization = tuning_shop.saved_customization.duplicate(true)
			add_child(tuning_shop)
	)


func toggle_ghost() -> void:
	show_ghost = not show_ghost
	ghost.prepare(self)
	save_preferences()


func toggle_fps() -> void:
	show_fps = not show_fps
	save_preferences()


func toggle_motion() -> void:
	motion_reduced = not motion_reduced
	motion_user_set = true
	save_preferences()


func relative_gap(other: float, reference: float) -> float:
	return wrapf(other - reference, -track.length / 2, track.length / 2) if mode == "track" else other - reference


func race_position() -> int:
	return competitor_position(-1)


func competitor_position(id: int) -> int:
	var progress: float = distance if id < 0 else rivals[id].distance
	var place := 1
	if id >= 0 and distance > progress + 0.001:
		place += 1
	for r in rivals:
		if not r.active or r.id == id:
			continue
		if r.distance > progress + 0.001 or (absf(r.distance - progress) <= 0.001 and r.id > id):
			place += 1
	return place


func restart(start_countdown: bool = true) -> void:
	hazard_text = ""
	if track.active.closed_loop and track.active.course_id == 3:
		track.scenery.rock_arches.reset_effect()
	haptics.stop()
	edge_rumble = 0
	crash.reset()
	recovery.reset()
	protection_left = 0
	player.set_protection(false)
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0, player.ride_offset, 0)
	recovery_distance = 80
	recovery_lane = -3.2
	if mode == "tour" and (track.active.stage != 0 or not track.history.is_empty()):
		track.reset()
	if track.active.collapse != null:
		track.active.collapse.reset_effect()
	if track.active.rockfall != null:
		track.active.rockfall.reset_effect()
	preload("res://scripts/environment/roadside_guidance.gd").reset(track.active)
	preload("res://scripts/environment/advertisement_library.gd").reshuffle(get_tree())
	track_environment.activate(self)
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
	run_medal = 0
	tour_score_multiplier = 1
	if record_key() != loaded_record_key:
		load_record()
	rewards.reset()
	sound_state.reset()
	proximity_audio.reset()
	slipstream.reset()
	acoustics.reset()
	passport.new_unlocks.clear()
	apply_cosmetics()
	route_challenges.reset()
	max_drift_multiplier = 1
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
	rain_lens.reset()
	bump_cooldown = 0
	launch_flash = 0
	camera_offset = Vector3.ZERO
	camera_intro = 0
	state = RaceState.COUNTDOWN if start_countdown else RaceState.READY
	initialize_traffic()
	if world_race != null:
		world_race.reset()
		if mode == "track" and selected_course == 1:
			preload("res://scripts/race/rolling_start.gd").begin(self)
	tire_trails.reset()
	player.reset_driving_effects()
	place_cars()
	update_camera(1)
	player.reset_physics_interpolation()
	camera.reset_physics_interpolation()
	for r in rivals:
		r.car.reset_physics_interpolation()
	personal_run.prepare(self)
	ghost.prepare(self)
	# A screen transition can finish after the device rotated to portrait. The
	# rotate guide hides the road, so wait paused rather than run unseen.
	if shell.portrait:
		pause_tour()


func _input(event: InputEvent) -> void:
	controls.handle(event)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		return
	# A pad that disappears mid-race must not leave the car steering or boosting on its own.
	pad.clear()
	if Input.get_connected_joypads().is_empty():
		gamepad_active = false
	pause_tour()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not navigate_back() and OS.has_feature("android"):
			get_tree().quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if hud != null:
			hud.fingers.clear()
		pad.clear()
		pause_tour()


func pause_tour() -> void:
	if state in RaceState.DRIVING:
		haptics.stop()
		resume_state = state
		state = RaceState.PAUSED
		if hud != null:
			hud.fingers.clear()


func resume_tour() -> void:
	if shell.portrait:
		return
	if state == RaceState.PAUSED:
		hud.fingers.clear()
		state = resume_state


func load_record() -> void:
	best_time = 0
	previous_best = 0
	new_record = false
	loaded_record_key = record_key()
	if not record_cache_loaded or state not in RaceState.DRIVING:
		record_store = ConfigFile.new()
		record_store.load("user://records.cfg")
		record_cache_loaded = true
	best_time = float(record_store.get_value(RECORD_GROUP, loaded_record_key, 0))
	if mode == "track" and selected_course == 1:
		track.active.speedway_board.bind(self)


func record_key() -> String:
	if mode == "tour":
		return "tour_routes_v2_" + str(vehicle.id) + "_" + TourChallenge.route_id(track.history)
	return Catalog.record_key(selected_vehicle, mode, selected_course)


func select_vehicle(index: int) -> void:
	if state != RaceState.READY:
		return
	if selected_vehicle == clampi(index, 0, Catalog.SPECS.size() - 1):
		return
	var old_index := selected_vehicle
	selected_vehicle = clampi(index, 0, Catalog.SPECS.size() - 1)
	hud.vehicle_changed(old_index)
	vehicle = Catalog.spec(selected_vehicle)
	remove_child(player)
	player.queue_free()
	player = Factory.create(selected_vehicle)
	add_child(player)
	apply_cosmetics()
	reset_nitro()
	load_record()
	if world_race != null:
		world_race.reset()
	place_cars()
	update_camera(1)
	personal_run.prepare(self)
	ghost.prepare(self)
	if previews != null:
		previews.show_vehicle(selected_vehicle)


func open_garage() -> void:
	restart(false)
	if previews != null:
		previews.show_vehicle(selected_vehicle)


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
	rain_lens.reset()
	nitro_active = false
	nitro_burst_left = 0
	nitro_pending = false
	cell_pending = false
	boosting = false


func gear_number() -> int:
	if world_race != null and world_race.reversing:
		return -1
	if speed < 0.3:
		return 0
	return clampi(ceili(speed / (vehicle.max_speed / 5.8)), 1, 6)


func engine_rpm() -> float:
	if (
		state
		in [
			RaceState.MENU, RaceState.COURSES, RaceState.READY, RaceState.SETTINGS, RaceState.FINISHED, RaceState.FAILED
		]
	):
		return 0
	var band: float = vehicle.max_speed / 5.8
	var gear := maxi(1, gear_number())
	var progress := clampf((speed - (gear - 1) * band) / band, 0, 1)
	return clampf(900 + progress * 6400, 900, 7500)


func nitro_ratio() -> float:
	if vehicle.mode == "charges":
		return (nitro_charges + nitro_burst_left / vehicle.burst_duration) / vehicle.charges
	return nitro / 100


func _physics_process(delta: float) -> void:
	Engine.time_scale = (
		(GAME_PACE if state in RaceState.DRIVING else 1.0) * (0.15 if Time.get_ticks_msec() < hitstop_until else 1.0)
	)
	return_flash = maxf(0, return_flash - delta)
	update_atmosphere(delta)
	if state == RaceState.COUNTDOWN:
		if mode == "track" and selected_course == 1:
			preload("res://scripts/race/rolling_start.gd").advance(self, minf(delta, countdown))
		countdown -= delta
		if countdown <= 0:
			if mode == "track" and selected_course == 1:
				preload("res://scripts/race/rolling_start.gd").release(self)
			state = RaceState.RACING
			launch_flash = 0.7
	if state == RaceState.RACING:
		var axis := (
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		)
		axis = clampf(axis + hud.touch_axis() + pad.steer(), -1, 1)
		var nitro_input := Input.is_physical_key_pressed(KEY_SHIFT) or hud.held("nitro") or pad.nitro()
		var cell_input := Input.is_physical_key_pressed(KEY_E) or hud.held("cell") or pad.cell()
		var gas := (
			auto_accelerate
			or Input.is_physical_key_pressed(KEY_W)
			or Input.is_physical_key_pressed(KEY_UP)
			or hud.held("gas")
			or pad.gas()
			or nitro_input
		)
		var brake := (
			Input.is_physical_key_pressed(KEY_S)
			or Input.is_physical_key_pressed(KEY_DOWN)
			or hud.held("brake")
			or pad.brake()
		)
		step(
			delta,
			axis,
			Input.is_physical_key_pressed(KEY_SPACE) or hud.held("drift") or pad.drift(),
			gas,
			brake,
			nitro_input,
			cell_input
		)
	place_cars(delta)
	acoustics.advance(self, delta)
	ghost.update(self)
	sync_world_rendering()
	var world_visible := not rendering_viewport.disable_3d
	shoulder_dust_clock = maxf(0, shoulder_dust_clock - delta)
	shoulder_dust.visible = world_visible and state == RaceState.RACING
	if state == RaceState.RACING and offroad_amount > 0.25 and speed > 12 and not air.active:
		if shoulder_dust_clock <= 0:
			shoulder_dust.burst(player.position if world_race != null else track.point(distance - 2, lane), true)
			shoulder_dust_clock = 0.24
	else:
		shoulder_dust.particles.emitting = false
	tire_trails.update(self)
	speed_ambience.update(self)
	var road_material: ShaderMaterial = track.active.road_surface.material_override
	if ground_contact_material != road_material:
		if ground_contact_material != null:
			ground_contact_material.set_shader_parameter("contact_strength", 0.0)
		ground_contact_material = road_material
	if world_race != null:
		var body: CharacterBody3D = world_race.player_body
		road_material.set_shader_parameter("contact_position", body.feet_position())
		road_material.set_shader_parameter("contact_normal", body.surface_normal)
		var forward: Vector3 = body.forward_direction()
		road_material.set_shader_parameter("contact_forward", Vector2(forward.x, forward.z).normalized())
		road_material.set_shader_parameter(
			"contact_strength", 1.0 if body.grounded and state in RaceState.DRIVING else 0.0
		)
	rain_lens.update(self, delta)
	var speed_blur_enabled: bool = not motion_reduced and speed > 35 and render_budget.level < 2
	speed_effect.visible = state == RaceState.RACING and (speed_blur_enabled or rain_lens.amount > .01)
	speed_effect.material.set_shader_parameter(
		"strength", clampf((speed - 35) / 53 * 1.2, 0, 1) if speed_blur_enabled else 0.0
	)
	speed_effect.material.set_shader_parameter("lens_amount", rain_lens.amount)
	speed_effect.material.set_shader_parameter("lens_clock", rain_lens.clock)
	speed_effect.material.set_shader_parameter(
		"high_quality", render_budget.level == 0 and not render_budget.is_mobile_platform
	)
	update_camera(delta)
	player.road_speed = speed if state == RaceState.RACING else 0.0
	player.effects_quality = render_budget.level
	player.reduced_motion = motion_reduced
	player.boost_shot = nitro_burst_left > 0
	player.shift_amount = sound_state.shift
	player.set_protection(protection_left > 0)
	player.animate(
		steer,
		drifting and not air.active and state == RaceState.RACING,
		(nitro_active or pad_active or reward_boost_active()) and state == RaceState.RACING,
		0.0 if state == RaceState.PAUSED else delta,
		0.0 if world_race != null else slip_angle,
		braking and state == RaceState.RACING,
		impact if state == RaceState.RACING and not motion_reduced else 0.0
	)
	if crash.active:
		apply_crash_pose()
	if offroad_amount > 0.2:
		for particles in player.smoke:
			particles.emitting = false
	var night: bool = (
		track_environment.headlights(self)
		if track_environment.supported(self)
		else track.scenery.theme in ["neon", "night"]
	)
	player.set_headlights(track.active.in_tunnel(distance) or night)
	for rival_index in range(rivals.size()):
		var r: RivalState = rivals[rival_index]
		r.car.set_headlights(r.active and (night or track.active.in_tunnel(r.distance)), false)
		if not r.active or not r.car.visible or absf(relative_gap(r.distance, distance)) > 145:
			if r.visual_running:
				r.car.animate(0, false, false, 0)
				r.car.body_motion.reset()
			r.visual_running = false
			continue
		r.visual_running = true
		if rival_index + 1 < world_race.bodies.size() and state == RaceState.RACING:
			var physical: CharacterBody3D = world_race.bodies[rival_index + 1]
			r.car.body_motion.sample(delta, physical.velocity, physical.global_basis, physical.grounded)
		r.car.road_speed = r.speed if state == RaceState.RACING else 0.0
		r.car.animate(
			clampf((r.target_lane - r.lane) / 2, -1, 1),
			(
				r.active
				and r.drifting
				and r.car.visible
				and absf(relative_gap(r.distance, distance)) < 80
				and state == RaceState.RACING
			),
			r.boosting and state == RaceState.RACING,
			0.0 if state == RaceState.PAUSED else delta,
			0
		)
	# HUD._process owns its redraw; physics ticks need not enqueue it again.


func sync_world_rendering() -> void:
	if not is_instance_valid(rendering_viewport) or not is_instance_valid(player):
		return
	preload("res://scripts/environment/roadside_guidance.gd").sync_visuals(self)
	var world_visible := warming_world or state not in RaceState.MENUS
	camera.far = 3000.0 if mode == "tour" and track.scenery.theme == "seoul" else 1800.0
	# GLES3는 첫 렌더 전 교체된 Sky의 대기 중 큐브맵을 남길 수 있다.
	# 가려진 코스 선택에서는 만들지 않고 실제 렌더·프리워밍 때 생성한다.
	if world_visible and atmosphere.sky == null:
		if mode == "track":
			atmosphere.sky = track.scenery.make_sky()
			track_environment.configure_sky(self)
		else:
			var sky := Sky.new()
			sky.sky_material = sky_colors
			sky.radiance_size = Sky.RADIANCE_SIZE_128
			atmosphere.sky = sky
			if not is_instance_valid(goal_background):
				goal_background = preload("res://scripts/environment/tour_goal_background.gd").new()
				goal_background.race = self
				add_child(goal_background)
			goal_background.route_id = -1
			if not is_instance_valid(tour_weather):
				tour_weather = preload("res://scripts/environment/tour_weather.gd").new()
				tour_weather.race = self
				player.get_parent().add_child(tour_weather)
	if world_visible and track_environment.supported(self) and not is_instance_valid(tour_weather):
		tour_weather = preload("res://scripts/environment/tour_weather.gd").new()
		tour_weather.race = self
		player.get_parent().add_child(tour_weather)
		tour_weather.configure(track_environment.active_weather)
	if world_visible and mode == "tour" and is_instance_valid(goal_background):
		goal_background._process(0)
	rendering_viewport.disable_3d = not world_visible
	if is_instance_valid(track):
		track.visible = world_visible
		# Pause decorative animation without removing road collision bodies from
		# the physics space (PROCESS_MODE_DISABLED would also disable colliders).
		if track.scenery.has_method("_process"):
			track.scenery.set_process(world_visible)
	player.visible = world_visible
	tire_trails.visible = world_visible
	if not world_visible:
		for r in rivals:
			r.car.visible = false


func step(
	delta: float,
	axis: float,
	drift_input: bool,
	gas: bool,
	brake: bool,
	nitro_input: bool = false,
	cell_input: bool = false
) -> void:
	edge_rumble = move_toward(edge_rumble, 0, delta * 4)
	haptics.enabled = not motion_reduced
	if crash.advance(delta):
		player.body.rotation.x = 0
		player.body.rotation.z = 0
		player.body.position = Vector3(0, player.ride_offset, 0)
	update_recovery(delta)
	if crash.active:
		axis = 0
		drift_input = false
		gas = false
		brake = false
		nitro_input = false
		cell_input = false
	hazard_text = ""
	world_race.step(delta, axis, drift_input, gas, brake, nitro_input, cell_input)
	var physical: CharacterBody3D = world_race.player_body
	player.body_motion.sample(delta, physical.velocity, physical.global_basis, physical.grounded and not crash.active)
	sound_state.advance(self, delta)
	proximity_audio.update(self, delta)
	if track.active.collapse != null:
		track.active.collapse.advance(delta, distance, motion_reduced)
		hazard_text = track.active.collapse.warning(distance)
	if track.active.rockfall != null:
		track.active.rockfall.advance(delta, distance, laps_completed, speed)
		var rock_warning: String = track.active.rockfall.warning(distance)
		if not rock_warning.is_empty():
			hazard_text = rock_warning
	preload("res://scripts/environment/roadside_guidance.gd").advance(self, delta)

	if track.active.closed_loop and track.active.course_id == 3:
		hazard_text = preload("res://scripts/track/riviera_profile.gd").warning(fposmod(distance, track.length))
		track.scenery.rock_arches.advance(delta, distance, laps_completed)
		var arch_warning: String = track.scenery.rock_arches.warning(distance)
		if not arch_warning.is_empty():
			hazard_text = arch_warning


func pad_speed_cap() -> float:
	return maxf(vehicle.overdrive_speed + 2, vehicle.max_speed + 21)


func reward_boost_active() -> bool:
	return state == RaceState.RACING and rewards.exit_boost > 0 and throttling and not drifting and not crash.active


func update_recovery(delta: float) -> void:
	var forward: Vector3 = (track.point(distance + 3) - track.point(distance - 3)).slide(Vector3.UP).normalized()
	var heading: Vector3 = world_race.player_body.forward_direction().slide(Vector3.UP).normalized()
	recovery.advance(delta, world_race.player_body.feet_position(), forward, acos(clampf(heading.dot(forward), -1, 1)))


func apply_crash_pose() -> void:
	# Rotate about the chassis centre, so a barrel roll cannot orbit the road
	# contact point or bury the model beneath the visible road on touchdown.
	var pivot := Vector3(0, 0.7, 0)
	player.body.rotation = Vector3(crash.visual_pitch, 0, crash.visual_roll)
	player.body.position = Vector3(0, player.ride_offset, 0) + pivot - player.body.basis * pivot


# Back on the road after leaving it past the guardrail; no button, no waiting.
func return_to_road() -> void:
	if world_race == null or state != RaceState.RACING:
		return
	if not world_race.recover_player():
		return
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0, player.ride_offset, 0)
	speed = world_race.RoadRecovery.RESUME_SPEED
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
	if not recovery_available:
		return
	var launches: int = air.launches
	var landings: int = air.landings
	if not world_race.recover_player():
		return
	crash.reset()
	recovery.reset()
	player.body.rotation.x = 0
	player.body.rotation.z = 0
	player.body.position = Vector3(0, player.ride_offset, 0)
	speed = world_race.RoadRecovery.RESUME_SPEED
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
	player.reset_driving_effects()
	place_cars()
	update_camera(1)
	player.reset_physics_interpolation()
	camera.reset_physics_interpolation()


func route_choices_visible() -> bool:
	return (
		mode == "tour"
		and state == RaceState.RACING
		and stage_index < Library.STAGES - 1
		and checkpoint_stage == stage_index
	)


func select_route(side: int) -> void:
	if not route_choices_visible():
		return
	route_preference = clampi(side, 0, 1)
	route_choice_flash = 0.4
	if screen_transition != null and sound_enabled:
		screen_transition.transition_sound.play()


func award_checkpoint() -> void:
	if checkpoint_stage == stage_index:
		return
	checkpoint_stage = stage_index
	checkpoints += 1
	checkpoint_flash = 2
	checkpoint_award = Library.checkpoint_bonus(route_node)
	time_left += checkpoint_award
	nitro = minf(100, nitro + 15)
	nitro_charges = mini(vehicle.charges, nitro_charges + 1)


func advance_route() -> void:
	recovery.reset()
	recovery_distance = 5
	recovery_lane = 0
	var choice := 0 if lane < 0 else 1
	var result := track.advance(choice, distance, lane)
	tour_score_multiplier = TourChallenge.score_multiplier(track.history)
	if record_key() != loaded_record_key:
		load_record()
	completed_distance += result.old_length
	distance = result.distance
	lane = result.lane
	route_preference = -1
	route_confirm_flash = 1.4
	route_confirm_title = route_banner()
	for rival in rivals:
		rival.active = false


func finish() -> void:
	if state == RaceState.FINISHED:
		return
	if record_key() != loaded_record_key:
		load_record()
	state = RaceState.FINISHED
	cancel_nitro()
	drifting = false
	boosting = false
	if mode == "tour":
		tour_score_multiplier = TourChallenge.score_multiplier(track.history)
		score = (score + int(time_left) * 100) * tour_score_multiplier
		run_medal = TourChallenge.medal(elapsed, track.history, vehicle.max_speed)
	if mode == "track":
		run_medal = 3 if race_position() == 1 else (2 if race_position() <= 3 else 1)
	previous_best = best_time
	new_record = best_time == 0 or elapsed < best_time
	if new_record:
		best_time = elapsed
	if save_records:
		var saved := ConfigFile.new()
		saved.load("user://records.cfg")
		saved.set_value(RECORD_GROUP, record_key(), best_time)
		if mode == "tour":
			var medal_key := record_key() + "_medal"
			saved.set_value(RECORD_GROUP, medal_key, maxi(run_medal, int(saved.get_value(RECORD_GROUP, medal_key, 0))))
		saved.save("user://records.cfg")
	personal_run.finish(self, true)
	passport.finish(self)


func register_impact(strength: float, normal: Vector2, world_at: Vector3 = Vector3.INF) -> void:
	# Separation and speed loss happen at the contact site. Feedback is emitted
	# once per cooldown, and parked/gentle contacts do not create a crash burst.
	if bump_cooldown > 0:
		return
	strength = clampf(strength, 0, 1)
	if strength < 0.07:
		strength = 0
	impact = maxf(impact, strength)
	impact_normal = normal.normalized()
	impact_recoil = strength
	impact_age = 0
	# A freeze-frame on hard hits makes them land (skipped with reduced motion).
	if strength > 0.55 and not motion_reduced:
		hitstop_until = Time.get_ticks_msec() + int(50 + strength * 70)
	if strength > 0:
		haptics.pulse(0.35 + 0.65 * strength, 0.5 + 0.5 * strength, 0.1 + 0.3 * strength, 3)
	cancel_nitro()
	drifting = false
	drift_charge = 0
	drift_latched = false
	drift_pending = 0
	bump_cooldown = 0.45
	if strength > 0 and DisplayServer.get_name() != "headless":
		var f := (track.point(distance + 2) - track.point(distance)).normalized()
		if world_race != null:
			f = world_race.player_body.forward_direction()
		var right := Vector3(-f.z, 0, f.x)
		var at := track.point(distance, lane) + Vector3.UP * 0.55 - right * normal.x * 1.25 + f * normal.y * 2.0
		if world_at.is_finite():
			at = world_at
		impacts.burst(at, -right * normal.x + f * normal.y - f * 0.7, motion_reduced, strength)


# Called every frame the car grinds along a rail: rumble, camera shake and a stream of sparks.
func scrape(delta: float, outward: Vector3, at: Vector3) -> void:
	edge_rumble = 1.0
	haptics.pulse(0.25, 0.6, 0.08, 1)
	scrape_timer -= delta
	if scrape_timer > 0 or impact_age < 0.5:
		return
	scrape_timer = 0.14 if motion_reduced else 0.07
	if DisplayServer.get_name() == "headless":
		return
	var f := (track.point(distance + 2) - track.point(distance)).normalized()
	if world_race != null:
		f = world_race.player_body.forward_direction()
	impacts.burst(at, -f * 0.9 - outward * 0.25, motion_reduced, 0.3)


func place_cars(_delta: float = 1.0) -> void:
	world_race.place_cars()


func _process(delta: float) -> void:
	render_budget.tick(self)
	controls.pad_stick_navigation(delta)


func collision_camera_offset(forward: Vector3, right: Vector3) -> Vector3:
	if state != RaceState.RACING or motion_reduced or impact_age > 0.42:
		return Vector3.ZERO
	# A quick directional compression and a single diminishing rebound rather
	# than an arbitrary shake that looks identical for left and right impacts.
	var pulse := impact_recoil * exp(-impact_age * 16) * cos(impact_age * 22)
	return (
		(right * impact_normal.x * 0.48 - forward * impact_normal.y * 0.36 + Vector3.UP * 0.055)
		* pulse
		* (1.0 + impact_recoil * 1.6)
	)


func update_camera(delta: float) -> void:
	world_race.update_camera(delta)


func update_atmosphere(delta: float) -> void:
	lighting.update(delta)


func cycle_track_weather() -> void:
	track_environment.cycle_weather()
	save_preferences()


func cycle_track_period() -> void:
	track_environment.cycle_period()
	save_preferences()
