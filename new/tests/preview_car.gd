extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.state = "racing"
	race.distance = 280
	race.speed = 60
	race.time_left = 35
	race.place_cars()
	race.update_camera(1)
	for view in ["rear","front","side"]:
		race.hud.visible = view == "rear"
		if view != "rear":
			for r in race.rivals: r.car.visible = false
			race.camera.position = race.player.to_global(Vector3(-4.4,2.2,-6) if view == "front" else Vector3(5.3,2.1,4.9))
			race.camera.look_at(race.player.position+Vector3.UP*0.8)
			race.camera.fov = 48
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/ae86-%s.png" % view)
		print("AE86 ",view)
	race.queue_free()
	await process_frame
	quit()
