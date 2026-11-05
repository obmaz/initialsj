extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = true
	for state in ["ready", "paused", "finished"]:
		race.state = state
		for i in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/menu-%s.png" % state)
	race.queue_free()
	await process_frame
	await process_frame
	quit()
