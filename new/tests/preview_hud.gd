# Visual fixture only: reference values never enter the production race.
# Run with a display: godot --path new --script res://tests/preview_hud.gd
extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "racing"
	var map_progress: float = race.hud.minimap_route.get_closest_offset(Vector2(1109, 156)) / race.hud.minimap_route.get_baked_length()
	race.distance = race.track.length * (1 + map_progress)
	race.speed = 248.0 / 3.6
	race.elapsed = 84.683
	race.nitro = 66.7
	race.score = 356
	race.drifting = true
	race.hud.coin_balance = 2460
	for i in range(race.rivals.size()):
		race.rivals[i].distance = race.distance - race.track.length * (1 if i == 0 else 2) + (30.0 + i * 35.0 if i < 2 else -50.0 - i * 10.0)
	race.place_cars()
	race.update_camera(1)
	race.hud._process(0.016)
	race.hud.set_process(false)
	race.hud.queue_redraw()
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/hud-preview.png")
	quit()
