extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	await process_frame
	check(race.rivals.size() == 7, "Eight racers must be present")
	var track = race.track
	check(track.point(0).distance_to(track.point(track.length)) < 0.001, "Course must form a closed loop")
	var road_arrays = track.road_surface.mesh.surface_get_arrays(0)
	check(road_arrays[Mesh.ARRAY_TEX_UV].size() > 0, "Generated asphalt must have road UV coordinates")
	check(road_arrays[Mesh.ARRAY_NORMAL][0].y > 0.8, "Road faces must point upward so the asphalt is visible")
	var water_arrays = track.scenery.water.mesh.surface_get_arrays(0)
	check(water_arrays[Mesh.ARRAY_NORMAL][0].y > 0.9, "Lake surface must face upward")
	check(track.scenery.tree_positions.size() > 0, "Generated foliage must be placed along the course")
	check(track.prop_batches.size() > 0, "Roadside props must be batched for web rendering")
	for texture in [track.scenery.PINE, track.scenery.SAKURA]:
		check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Foliage must have a transparent background")
	for progress in [0.0, 0.25, 0.5, 0.75]:
		var d: float = track.length * progress
		check(track.scenery.terrain_point(d, track.scenery.SHORE_LANE).y > track.scenery.WATER_HEIGHT, "Shoreline must stay above lake level")

	check(track.point(-5).distance_to(track.point(track.length - 5)) < 0.001, "Negative start-grid distances must wrap")
	check(race.hud.map_point(0).distance_to(race.hud.map_point(track.length)) < 0.01, "HUD route must close at the lap boundary")
	check(race.hud.map_point(-5).distance_to(race.hud.map_point(track.length - 5)) < 0.01, "Starting grid markers must wrap on the HUD route")
	check(race.hud.map_point(track.length - 0.01).distance_to(race.hud.map_point(0)) < 0.1, "HUD markers must not jump at the finish line")
	for progress in [0.0, 0.25, 0.5, 0.75]:
		check(Rect2(1090, 70, 180, 120).has_point(race.hud.map_point(track.length * progress)), "HUD route must stay inside its safe area")
	race.restart()
	race.state = "racing"
	# Move opponents clear of the player for deterministic control checks.
	for rival in race.rivals:
		rival.distance = track.length * 0.5
	for i in range(600):
		race.step(1.0 / 60, 0, false, false, false)
	check(race.speed > 50 and race.distance > 300, "Auto acceleration must move the car")
	var charge: float = race.nitro
	for i in range(60):
		race.step(1.0 / 60, 0, false, true, false)
	check(race.nitro < charge and race.speed > 56, "Nitro must consume reserve and increase speed")
	charge = race.nitro
	for i in range(30):
		race.step(1.0 / 60, 1, true, false, false)
	check(race.score > 0 and race.nitro > charge, "Drifting must award score and regenerate nitro")
	for i in range(300):
		race.step(1.0 / 60, 1, false, false, false)
	check(absf(race.lane) <= 7.8 and race.speed < 40, "Shoulders must contain and slow the car")
	race.lane = 3
	race.speed = 56
	race.bump_cooldown = 0
	race.rivals[0].lane = 3
	race.rivals[0].distance = race.distance
	race.step(1.0 / 60, 0, false, false, false)
	check(race.bump_cooldown > 0 and race.speed < 45, "Contact must reduce speed")
	race.distance = track.length * 3 - 0.1
	race.step(1.0 / 60, 0, false, false, false)
	check(race.state == "finished", "Race must finish after three laps")
	race.restart()
	check(race.distance == 0 and race.score == 0 and race.nitro == 100 and race.state == "countdown", "Restart must reset race state")
	race.hud.fingers[0] = Vector2(70, 630)
	race.hud.fingers[1] = Vector2(960, 616)
	check(race.hud.touch_axis() == -1 and race.hud.held("boost"), "Multi-touch steering and boost must work together")
	check(not race.hud.hit_button("left", Vector2(28, 563)), "Circular controls must ignore transparent corners")
	# The inverse transform must keep touch targets aligned on ultrawide and portrait windows.
	for viewport_size in [Vector2i(1920, 1080), Vector2i(2340, 1080), Vector2i(390, 844)]:
		root.size = viewport_size
		var center: Vector2 = race.hud.buttons.boost.get_center()
		var screen: Vector2 = center * race.hud.ui_scale() + race.hud.ui_offset()
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.position = screen
		touch.pressed = true
		race.state = "racing"
		race.hud.fingers.clear()
		race.hud.handle_pointer(touch)
		check(race.hud.held("boost"), "Boost hit target must align after resizing")
		touch.pressed = false
		race.hud.handle_pointer(touch)
		check(not race.hud.held("boost"), "Touch release must clear the button")
	root.size = Vector2i(1280, 720)
	race.hud.fingers[0] = Vector2(70, 630)
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.index = 8
	pause_touch.position = race.hud.buttons.pause.get_center() * race.hud.ui_scale() + race.hud.ui_offset()
	pause_touch.pressed = true
	race.hud.handle_pointer(pause_touch)
	check(race.state == "paused" and race.hud.fingers.is_empty(), "Touch pause must clear held driving controls")
	race.hud.handle_pointer(pause_touch)
	check(race.state == "racing", "Lap panel must also resume the race")
	print("Race checks: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
