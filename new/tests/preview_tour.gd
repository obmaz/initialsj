extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	var scenes := [[0,0,280,"hawaii"],[1,0,450,"desert"],[1,1,650,"city"],[2,0,440,"pyramid"],[2,1,510,"amusement"],[2,2,300,"jeju"],[3,0,650,"ruins"],[3,1,650,"seoul"],[0,0,480,"canopy"],[1,1,1110,"tunnel"],[0,0,1495,"fork"],[2,2,810,"hill"],[0,0,650,"drift"],[1,1,580,"impact"],[2,1,670,"speed"]]
	for setup in scenes:
		race.track.reset(setup[0],setup[1])
		race.state = "racing"
		race.distance = setup[2]
		race.speed = 75
		race.impact = 0
		race.boosting = false
		race.drafting = false
		race.draft_charge = 0
		race.throttling = true
		race.time_left = 35
		race.elapsed = 8
		race.lane = -2
		race.lane_velocity = 0
		race.steer = 0
		race.slip_angle = 0
		race.drifting = false
		race.camera_offset = Vector3.ZERO
		if setup[3] == "drift":
			race.drifting = true
			race.steer = -0.55
			race.slip_angle = 0.48
		if setup[3] == "impact":
			race.lane = 8
			race.impact = 1
		if setup[3] == "speed":
			race.speed = 88
			race.boosting = true
			race.drafting = true
			race.draft_charge = 1
		race.place_cars()
		race.player.road_speed = race.speed
		race.player.animate(race.steer,race.drifting,false,1.0/60,race.slip_angle,false,race.impact)
		race.speed_ambience.update(race)
		race.update_camera(1)
		race.speed_effect.visible = setup[3] in ["speed","drift","impact"]
		race.speed_effect.material.set_shader_parameter("strength",1.0 if setup[3] == "speed" else 0.5)
		if setup[3] == "drift": await create_timer(0.08).timeout
		for i in range(6): await process_frame
		if setup[3] == "impact":
			race.register_impact(1,Vector2(-1,0))
			await create_timer(0.10).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/tour/%s.png" % setup[3])
		print("Captured ",setup[3])
	race.queue_free()
	await process_frame
	await process_frame
	quit()
