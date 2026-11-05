extends SceneTree
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name() == "headless":
		push_error("Render review requires a graphical display")
		quit(2)
		return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.state = "racing"
	race.speed = 75
	race.distance = 480
	race.place_cars()
	race.update_camera(1)
	for i in range(12): await process_frame
	var then := Time.get_ticks_usec()
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var report := {"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"average_frame_ms":(Time.get_ticks_usec()-then)/30000.0}
	print(JSON.stringify(report))
	var output := FileAccess.open("res://docs/render-metrics.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	race.queue_free()
	await process_frame
	quit()
