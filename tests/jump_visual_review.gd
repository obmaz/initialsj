extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(race: Node3D, name: String) -> void:
	race.place_cars()
	race.update_camera(1)
	race.update_atmosphere(2)
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
	for choice in [["tour",0,"jump-tour"],["track",0,"jump-fuji"],["track",1,"jump-seocho"]]:
		race.choose_mode(choice[0],choice[1])
		race.state = "racing"
		for r in race.rivals: r.active = false
		var ramp: Dictionary = race.track.active.features.filter(func(f): return f.kind == "ramp")[0]
		race.distance = ramp.distance-22
		race.lane = ramp.lane
		race.speed = 65
		if choice[2] == "jump-fuji": await capture(race,"jump-ramp")
		var edge: float = ramp.distance+ramp.length*0.5
		race.distance = edge+1
		race.air.advance(race.track.active,Vector2(ramp.lane,edge-1),Vector2(ramp.lane,edge+1),65,2.0/65)
		var old: float = race.distance
		race.distance += 65*0.48
		race.air.advance(race.track.active,Vector2(ramp.lane,old),Vector2(ramp.lane,race.distance),65,0.48)
		await capture(race,choice[2])
		if choice[2] == "jump-fuji":
			old = race.distance
			race.distance += 65*0.9
			var landing: Array[String] = race.air.advance(race.track.active,Vector2(ramp.lane,old),Vector2(ramp.lane,race.distance),65,0.9)
			if landing.has("land"): race.score += 100
			race.landing_dust.burst(race.track.point(race.distance,race.lane),false)
			race.landing_dust.particles.speed_scale = 0.2
			await capture(race,"jump-landing")
			race.landing_dust.particles.speed_scale = 1.0
	race.queue_free()
	await process_frame
	quit()
