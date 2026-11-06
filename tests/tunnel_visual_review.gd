extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	for mode in ["track","tour"]:
		race.choose_mode(mode)
		if mode == "tour": race.track.reset(1,1)
		race.state = "racing"
		for r in race.rivals: r.active = false
		var span: Vector2 = Vector2(race.track.length*0.56,race.track.length*0.56+240) if mode == "track" else race.Library.tunnel_span(1,1)
		for family in range(3):
			race.distance = span.x+35+32*family
			race.lane = -2
			race.speed = 60
			race.place_cars()
			race.update_camera(1)
			race.update_atmosphere(2)
			race.player.headlight.visible = true
			race.hud.queue_redraw()
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/tunnel-"+mode+"-"+str(family)+".png")
	race.queue_free()
	await process_frame
	quit()
