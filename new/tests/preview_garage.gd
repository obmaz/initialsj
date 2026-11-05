extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	DirAccess.make_dir_recursive_absolute("res://docs/garage")
	for i in range(3):
		race.open_garage()
		race.select_vehicle(i)
		for j in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/garage/select-%d.png" % i)
		race.state = "racing"
		race.distance = 280
		race.lane = 0
		race.speed = 85
		race.place_cars()
		race.update_camera(1)
		race.nitro_active = true
		if i > 0:
			race.nitro_burst_left = 1
			race.nitro_charges = 2 if i == 1 else 1
		race.player.animate(0,false,true,0.016)
		for view in ["rear","front"]:
			race.hud.visible = view == "rear"
			if view == "front":
				race.camera.position = race.player.to_global(Vector3(-3.8,1.9,-5.3))
				race.camera.look_at(race.player.position+Vector3.UP*0.7)
				race.camera.fov = 45
			for j in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/garage/%s-%s.png" % [race.vehicle.id,view])
		race.hud.visible = true
	race.queue_free()
	await process_frame
	await process_frame
	quit()
