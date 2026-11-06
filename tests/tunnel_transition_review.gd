extends SceneTree
const Report = preload("res://tests/report.gd")
const Rig = preload("res://scripts/tunnel_lights.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	Rig.pipeline_warmed = false
	race.navigate(func(): race.choose_mode("track",0))
	while race.screen_transition.busy:
		await process_frame
		if race.selected_course == 0 and race.camera.position.distance_to(race.player.position) > 100:
			check(race.screen_transition.cover.visible and race.screen_transition.cover.color.a >= 0.99,"Tunnel shader preparation must be hidden by an opaque transition")
	check(Rig.pipeline_warmed,"Prepared Fuji scene must render tunnel local-light variants before reveal")
	check(not race.is_physics_processing(),"Preparation must restore the caller's physics setting")
	check(race.camera.position.distance_to(race.player.position) < 20,"Preparation must restore the race camera")
	for mode in ["track","tour"]:
		race.choose_mode(mode)
		if mode == "tour": race.track.reset(1,1)
		race.state = "racing"
		for r in race.rivals: r.active = false
		var section: Node3D = race.track.active
		for i in range(section.curve_marker_transforms.size()):
			var actual: Transform3D = section.curve_markers.multimesh.get_instance_transform(i)
			check(actual.is_equal_approx(section.curve_marker_transforms[i]),"Renderer must receive the reviewed arrow transforms")
		var rig: Node3D = Rig.collect_rigs(section)[0]
		# A visible arrow position under each real tunnel shell.
		for d in section.curve_marker_distances:
			if not section.in_tunnel(d): continue
			race.distance = d-10
			race.lane = -2
			race.speed = 55
			race.place_cars()
			race.update_camera(1)
			race.update_atmosphere(2)
			race.player.reset_physics_interpolation()
			race.camera.reset_physics_interpolation()
			rig.update_lights(race.camera.position)
			race.hud.queue_redraw()
			for frame in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(Report.path("tunnel-fixed-"+mode+".png"))
			break
	print("Tunnel covered warm-up / camera restoration / actual render transforms: ","PASS" if failures == 0 else "FAIL")
	race.queue_free()
	for frame in range(3): await process_frame
	quit(1 if failures else 0)
