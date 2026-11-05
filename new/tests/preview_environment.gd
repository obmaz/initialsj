# Visual inspection of the generated environment in several driving directions.
extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	race.state = "racing"
	for i in range(360):
		race.step(1.0 / 60, 0, false, false, false)
	var first_distance: float = race.distance
	for i in range(4):
		var shift: float = race.track.length * i / 4.0
		race.distance = first_distance + shift
		for j in range(race.rivals.size()):
			race.rivals[j].distance = -10.0 - j * 9.0 + float(race.rivals[j].pace) * 6.0 + shift
		race.place_cars()
		race.update_camera(1)
		race.hud.queue_redraw()
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/fuji-view-%d.png" % i)
		print("Environment view ", i, " captured")
	quit()
