extends SceneTree
const Report = preload("res://tests/report.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	var rows := []
	for choice in [["tour",0],["track",0],["track",1]]:
		race.choose_mode(choice[0],choice[1])
		race.state = "racing"
		race.speed = 65
		race.distance = 80
		race.place_cars()
		race.update_camera(1)
		for quality in [1,2]:
			race.render_budget.set_mode(quality,race)
			for i in range(7): await process_frame
			await RenderingServer.frame_post_draw
			rows.append({"mode":choice[0],"course":choice[1],"quality":"HIGH" if quality == 1 else "FAST","root_draw_calls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"viewport":str(root.size)})
	print(JSON.stringify(rows))
	FileAccess.open(Report.path("render-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"environment":"native GL Compatibility / Mesa llvmpipe / 1280x720 frozen starting view","note":"Draw submissions only; not a hardware FPS benchmark or before/after web speed claim","views":rows},"\t")+"\n")
	race.queue_free()
	for frame in range(3): await process_frame
	quit()
