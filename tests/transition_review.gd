extends SceneTree
const Report = preload("res://tests/report.gd")
var failures := 0
var race: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func tap(rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = rect.get_center()*race.hud.ui_scale()+race.hud.ui_offset()
	race._input(event)
	event.pressed = false
	race._input(event)
func settled(expected: String) -> void:
	var timeout := Time.get_ticks_msec()+12000
	while race.screen_transition.busy and Time.get_ticks_msec() < timeout: await process_frame
	check(not race.screen_transition.busy and race.state == expected,"Transition must complete in "+expected)
	check(is_equal_approx(race.hud.modulate.a,1) and is_zero_approx(race.hud.position.x),"Transition must restore the UI transform")
	check(not race.screen_transition.cover.visible,"Transition cover must release the screen")
func shot(name: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Report.path(name+".png"))
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.save_records = false
	race.sound_enabled = false
	race.set_physics_process(false)
	await shot("flow-home")
	tap(race.hud.HOME_SETTINGS)
	check(race.screen_transition.busy,"Settings touch must begin an animated transition immediately")
	tap(race.hud.HOME_TRACK)
	await settled("settings")
	await shot("flow-settings")
	tap(race.hud.SETTINGS_CLOSE)
	await settled("menu")
	tap(race.hud.HOME_TRACK)
	await settled("courses")
	await shot("flow-courses")
	tap(race.hud.COURSE_FUJI)
	await settled("ready")
	var track_id: int = race.track.get_instance_id()
	for index in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		tap(race.hud.garage_card(index))
		check(race.selected_vehicle == index,"Garage touch selects the intended vehicle")
		for frame in range(18): await process_frame
	await shot("flow-garage")
	tap(race.hud.GARAGE_START)
	await settled("countdown")
	check(race.camera_intro > 0,"Game entry must begin the launch camera movement")
	check(race.track.get_instance_id() == track_id,"Starting a prepared course must not rebuild its environment")
	await shot("flow-start")
	race.state = "racing"
	race.speed = 65
	race.update_camera(0.6)
	await shot("flow-racing")
	check(race.hud.rpm_ring.visible,"The live RPM bar must stay visible during the race")
	race.pause_tour()
	await shot("flow-paused")
	tap(race.hud.MAIN_MENU_BUTTON)
	await settled("menu")
	check(race.hud.fingers.is_empty() and not race.nitro_active,"Returning to the menu must clear held driving controls")
	race.motion_reduced = true
	race.navigate(race.open_courses)
	await settled("courses")
	check(is_zero_approx(race.hud.position.x),"Reduced motion must not leave a slide offset")
	var scale := minf(896.0/1280,414.0/720)
	for rect in [race.hud.pause_touch_rect(),race.hud.MAIN_MENU_BUTTON,race.hud.HOME_SETTINGS,race.hud.GARAGE_BACK,race.hud.SETTINGS_SOUND,race.hud.SETTINGS_MOTION,race.hud.SETTINGS_GRAPHICS,race.hud.SETTINGS_INSTALL,race.hud.SETTINGS_CLOSE]:
		check(rect.size.y*scale >= 44,"Important touch controls must be at least 44 px on a landscape phone")
	print("Screen flow / repeated input / reduced motion / touch targets: ","PASS" if failures == 0 else "FAIL")
	race.queue_free()
	for frame in range(3): await process_frame
	quit(1 if failures else 0)
