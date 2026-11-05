# Controlled inputs for visual review; no game records are written.
extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.restart()
	race.state = "racing"
	for stage in range(4):
		for frame in range(180 if stage == 0 else 60):
			var drift := stage == 2
			var axis := -0.25 if drift else 0.0
			race.step(1.0 / 60, axis, drift, stage == 1, false)
			race.place_cars()
			race.tire_trails.update(race)
			race.player.road_speed = race.speed
			race.player.animate(race.steer, race.drifting, race.boosting or race.mini_turbo > 0, 1.0 / 60)
			race.update_camera(1.0 / 60)
			race.speed_effect.visible = true
			race.speed_effect.material.set_shader_parameter("strength", clampf((race.speed - 35) / 53, 0, 1))
			# Only render the last half-second: simulation remains deterministic and preview is quick.
			if frame > (149 if stage == 0 else 29):
				await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/feel-%d.png" % stage)
		print("Feel stage ",stage," / speed ",snappedf(race.speed * 3.6,0.1)," / rank ",race.rank_position())
	race.queue_free()
	await process_frame
	await process_frame
	quit()
