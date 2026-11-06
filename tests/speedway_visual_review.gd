extends SceneTree
var race: Node3D
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	race.place_cars()
	race.update_atmosphere(1)
	race.update_camera(1)
	race.player.reset_physics_interpolation()
	race.camera.reset_physics_interpolation()
	race.hud.queue_redraw()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+name+".png")
func run() -> void:
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.open_courses()
	await shot("speedway-course-select")
	race.choose_mode("track",1)
	race.state = "racing"
	race.speed = 85
	for r in race.rivals: r.active = false
	var peak := 0.0
	var peak_at := 0.0
	for i in range(1000):
		var d: float = race.track.length*i/1000
		if race.track.active.bank_at(d) > peak:
			peak = race.track.active.bank_at(d)
			peak_at = d/race.track.length
	print("Peak bank: ",rad_to_deg(peak)," at ",peak_at)
	for view in [[0.025,"speedway-start"],[peak_at,"speedway-bank"],[0.52,"speedway-backstraight"],[0.83,"speedway-turn-four"]]:
		race.distance = race.track.length*view[0]
		race.lane = 2
		race.camera_intro = 0
		await shot(view[1])
	# Actual model alignment, not an overlay faking the bank.
	assert(absf(race.player.rotation.z-race.track.active.bank_at(race.distance)) < 0.001)
	root.size = Vector2i(896,414)
	race.open_courses()
	await shot("speedway-mobile-select")
	race.queue_free()
	for frame in range(3): await process_frame
	quit()
