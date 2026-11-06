extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(race: Node3D, name: String) -> void:
	race.place_cars()
	race.update_atmosphere(1)
	race.update_camera(1)
	race.player.reset_physics_interpolation()
	race.camera.reset_physics_interpolation()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name+".png")
func run() -> void:
	root.size = Vector2i(896,414)
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	await shot(race,"mobile-home")
	race.open_courses()
	await shot(race,"mobile-courses")
	race.choose_mode("track",1)
	await shot(race,"mobile-garage")
	race.choose_mode("tour")
	race.state = "racing"
	race.speed = 78
	race.lane = -3
	for r in race.rivals: r.active = false
	race.distance = race.track.active.checkpoint_distance()+12
	race.award_checkpoint()
	await shot(race,"mobile-checkpoint-route")
	race.checkpoint_flash = 0
	race.distance += 300
	race.select_route(1)
	await shot(race,"mobile-route-choice")
	race.distance = race.track.length-80
	await shot(race,"mobile-route-approach")
	race.distance = race.track.length+35
	race.lane = 4
	await shot(race,"mobile-route-split")
	race.queue_free()
	for frame in range(3): await process_frame
	quit()
