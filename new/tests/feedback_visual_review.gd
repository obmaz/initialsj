extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String, race: Node3D) -> void:
	race.place_cars()
	race.update_camera(1)
	race.hud.queue_redraw()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name+".png")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("track")
	race.state = "racing"
	race.speed = 65
	race.distance = 480
	for rival in race.rivals:
		rival.distance = race.distance+25+rival.id*18
		rival.lane = -2.0 if rival.id%2 else 2.0
	await capture("track-race-markers",race)
	root.size = Vector2i(896,414)
	await capture("track-race-mobile",race)
	race.pause_tour()
	await capture("track-pause-mobile",race)
	root.size = Vector2i(1280,720)
	race.choose_mode("tour")
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	race.distance = 350
	race.lane = 8
	race.slip_angle = -0.45
	race.drifting = true
	race.speed = 65
	for i in range(25):
		race.distance += 1.5
		race.place_cars()
		race.tire_trails.update(race)
	await capture("wide-road-drift-trails",race)
	race.queue_free()
	for i in range(4): await process_frame
	quit()
