extends SceneTree
const Report = preload("res://tests/report.gd")
var failures := 0
var views: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func pose(race: Node3D, d: float, speed: float, drifting: bool = false) -> void:
	# Fuji cars are real world bodies. Teleport the physical chassis and then
	# synchronize the visual model; scalar race.distance is only telemetry.
	var session: Node3D = race.world_race
	session.teleport(0,d,-2)
	race.speed = speed
	race.drifting = drifting
	race.steer = -0.5 if drifting else 0
	race.slip_angle = 0.22 if drifting else 0
	race.hud.was_drifting = drifting
	race.hud.drift_fade = 1.5 if drifting else 0
	race.hud.drift_combo = 356 if drifting else 0
	race.hud.last_score = race.score
	var body: CharacterBody3D = session.player_body
	body.grounded = true
	body.velocity = body.forward_direction()*speed
	if drifting:
		body.global_basis = body.global_basis.rotated(body.surface_normal,0.22)
		body.slip_angle = 0.22
	for i in range(1,session.bodies.size()):
		session.teleport(i,fposmod(d+45+i*24,race.track.length),-2.4 if i%2 else 2.4)
		session.bodies[i].grounded = true
		session.bodies[i].velocity = session.bodies[i].forward_direction()*speed
		race.rivals[i-1].speed = speed
		race.rivals[i-1].car.reset_physics_interpolation()
	session.place_cars()
	race.player.reset_physics_interpolation()
	race.camera_offset = Vector3.ZERO
	race.camera_intro = 0
	race.update_camera(1)
	race.camera.reset_physics_interpolation()
	check(session.player_body.feet_position().distance_to(race.track.point(d,-2)) < 0.06,"Visual review must move the actual player chassis to its requested road point")

func capture(name: String, race: Node3D) -> void:
	race.update_atmosphere(2)
	race.world_race.place_cars()
	race.track.visible = true
	race.player.visible = true
	race.update_camera(1)
	race.player.road_speed = race.speed
	# Physical chassis yaw already includes slip, so the visual adds none.
	race.player.animate(race.steer,race.drifting,false,0.1,0)
	race.player.headlight.visible = race.track.active.in_tunnel(race.distance)
	for rival in race.rivals:
		if rival.active and rival.car.visible:
			rival.car.road_speed = rival.speed
			rival.car.animate(0,false,false,0.1,0)
	race.hud.queue_redraw()
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(Report.path(name+".png"))
	check(error == OK,"Could not save Fuji world-space visual review image")
	views.append({"image":name+".png","distance_m":race.distance,"feet":str(race.world_race.player_body.feet_position()),"car_position":str(race.player.position),"camera":str(race.camera.position),"bank_degrees":rad_to_deg(race.track.active.bank_at(race.distance)),"in_tunnel":race.track.active.in_tunnel(race.distance)})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run the Fuji visual review with a rendering display")
		quit(1)
		return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.choose_mode("track",0)
	check(race.world_race != null,"Fuji visual review requires the real world-space race controller")
	if race.world_race == null:
		quit(1)
		return
	# Allow the new static course and physical car bodies to enter the world.
	await physics_frame
	await physics_frame
	race.state = "racing"
	race.elapsed = 84.683
	race.motion_reduced = false
	var section: Node3D = race.track.active
	var length: float = section.length
	var max_curve := 0.0
	var hairpin := 0.0
	var minimum_y := INF
	var maximum_y := -INF
	var crest := 0.0
	for sample in range(1200):
		var d: float = length*sample/1200
		var curve: float = absf(race.track.curvature(d))
		if curve > max_curve: max_curve = curve; hairpin = d
		var y: float = race.track.point(d).y
		minimum_y = minf(minimum_y,y)
		if y > maximum_y: maximum_y = y; crest = d
	var tunnel: Vector2 = section.underpass_span()
	for view in [[tunnel.x-150,"fuji-underpass-approach"],[tunnel.x-50,"fuji-underpass-descent"],[80.0,"fuji-ridge-start"],[length*0.20,"fuji-ridge-climb"],[crest-25,"fuji-ridge-crest"],[hairpin-30,"fuji-ridge-hairpin"],[tunnel.x+110,"fuji-ridge-tunnel"],[tunnel.y-15,"fuji-ridge-tunnel-exit"],[section.bridge_lower_distance-35,"fuji-world-bridge-below"],[section.bridge_upper_distance-15,"fuji-world-bridge-above"],[length*0.83,"fuji-ridge-downhill"]]:
		race.state = "racing"
		pose(race,float(view[0]),42 if "hairpin" in view[1] else 65,"hairpin" in view[1])
		await capture(view[1],race)
	race.pause_tour()
	await capture("fuji-ridge-paused",race)
	FileAccess.open(Report.path("fuji-world-visual-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"length_m":length,"elevation_span_m":maximum_y-minimum_y,"tightest_radius_m":1/max_curve,"hairpin_m":hairpin,"views":views,"failures":failures},"\t")+"\n")
	print("Fuji world-space player / camera visual review: ","PASS" if failures == 0 else "FAIL","; ",views.size()," captures")
	race.queue_free()
	for frame in range(4): await process_frame
	quit(1 if failures else 0)
