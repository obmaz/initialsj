extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(race: Node3D, name: String) -> void:
	race.place_cars()
	race.update_atmosphere(2)
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
	race.open_courses()
	await shot(race,"circuit-select")
	race.choose_mode("track",1)
	race.state = "racing"
	for r in race.rivals: r.active = false
	print("Seocho length: ",race.track.length," / bounds ",race.track.map_bounds)
	for location in race.track.scenery.locations:
		race.distance = location.distance-28
		race.lane = 0
		race.speed = 48
		await shot(race,"seocho-"+str(race.track.scenery.locations.find(location)))
	race.queue_free()
	await process_frame
	quit()
