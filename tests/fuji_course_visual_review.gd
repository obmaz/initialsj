extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String, race: Node3D) -> void:
	race.update_atmosphere(2)
	race.place_cars()
	race.update_camera(1)
	race.player.road_speed = race.speed
	race.player.animate(race.steer,race.drifting,false,0.1,race.slip_angle)
	race.player.headlight.visible = race.track.active.in_tunnel(race.distance)
	race.hud.queue_redraw()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name+".png")
func run() -> void:
	var race=load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("track")
	race.state = "racing"
	var length: float = race.track.length
	var max_curve := 0.0
	var hairpin := 0.0
	var minimum_y := INF
	var maximum_y := -INF
	for sample in range(1200):
		var d := length*sample/1200
		var curve: float = absf(race.track.curvature(d))
		if curve > max_curve: max_curve = curve; hairpin = d
		var y: float = race.track.point(d).y
		minimum_y = minf(minimum_y,y)
		maximum_y = maxf(maximum_y,y)
	print(JSON.stringify({"length_m":length,"elevation_span_m":maximum_y-minimum_y,"tightest_radius_m":1/max_curve,"hairpin_m":hairpin}))
	for view in [[length*0.56-150,"fuji-underpass-approach"],[length*0.56-50,"fuji-underpass-descent"],[80.0,"fuji-ridge-start"],[length*0.22,"fuji-ridge-climb"],[hairpin-30,"fuji-ridge-hairpin"],[length*0.56+110,"fuji-ridge-tunnel"],[length*0.56+225,"fuji-ridge-tunnel-exit"],[length*0.83,"fuji-ridge-downhill"]]:
		race.distance = view[0]
		race.speed = 42 if "hairpin" in view[1] else 65
		race.lane = -2
		race.drifting = "hairpin" in view[1]
		race.steer = -0.5 if race.drifting else 0
		race.slip_angle = 0.35 if race.drifting else 0
		for rival in race.rivals:
			rival.distance = race.distance+50+rival.id*25
			rival.lane = -2.0 if rival.id%2 else 2.0
		await capture(view[1],race)
	race.pause_tour()
	await capture("fuji-ridge-paused",race)
	race.queue_free()
	for frame in range(4): await process_frame
	quit()
