extends SceneTree
const Contact = preload("res://scripts/car_contact.gd")
const Library = preload("res://scripts/route_library.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1
func clear_traffic(race: Node3D) -> void:
	for r in race.rivals:
		r.detached = null
		r.distance = 10000.0
func reset_drive(race: Node3D) -> void:
	race.restart()
	race.state = "racing"
	clear_traffic(race)
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	await process_frame
	check(race.track.point(0).distance_to(race.track.point(race.track.length)) > 1200,"Road must be open, not a closed lap")
	check(race.track.point(-10).distance_to(race.track.point(race.track.length-10)) > 1000,"Negative road positions must extrapolate rather than wrap")
	check(race.track.previews[0].point(300).distance_to(race.track.previews[1].point(300)) > 60,"Forks must be two physical roads")
	check(race.track.point(800).y > race.track.point(80).y+8,"Road must have real elevation")
	var arrays = race.track.road_surface.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_NORMAL][0].y > 0.8 and arrays[Mesh.ARRAY_TEX_UV].size() > 0,"Road must have upward faces and texture coordinates")
	var themes := {}
	for row in Library.THEMES:
		for theme in row: themes[theme] = true
	check(themes.size() == 15,"All fifteen route nodes must have different themes")
	for stage in range(4):
		for node in range(stage+1):
			check(Library.theme(stage+1,node) != Library.theme(stage+1,node+1),"Every fork must lead to different left and right themes")
	var art = race.track.scenery.roadside_art
	check(art.models.placements.size() > 30,"The actual starting road must instantiate a 3D regional foreground")
	for i in range(art.positions.size()):
		var p: Vector3 = art.positions[i]
		var d: float = race.track.active.curve.get_closest_offset(p)
		var width: float = art.widths[i]
		check(Vector2(p.x-race.track.point(d).x,p.z-race.track.point(d).z).length()-width*0.5 > race.track.half_width(d)+2,"Solid foreground bounds must stay outside the drivable road and rails")
	for path in range(16):
		var visited := {Library.theme(0,0):true}
		var node := 0
		for stage in range(1,5):
			node += (path >> (stage-1)) & 1
			var theme_id := Library.theme(stage,node)
			check(not visited.has(theme_id),"A complete tour must never repeat a theme")
			visited[theme_id] = true

	reset_drive(race)
	for i in range(158): race.step(1.0/60,0,false,true,false)
	check(race.speed > 55,"Gas must reach 200 km/h within 2.64 seconds")
	race.speed = 70
	race.distance = 80
	race.lane = 0
	race.lane_velocity = 0
	for i in range(120): race.step(1.0/60,0,false,true,true)
	check(race.speed < 0.01 and race.braking,"Brake must override gas and stop the car")
	reset_drive(race)
	race.speed = 70
	race.lane = 0
	race.step(0.1,-0.6,false,false,true)
	race.step(1.0/60,-0.6,false,true,false)
	check(race.drifting,"A short brake tap, steering and gas must initiate a drift")
	var entry: float = race.speed
	for i in range(45): race.step(1.0/60,-0.2,false,true,false)
	check(race.drifting and race.speed <= entry and race.speed > entry-1,"Drifting must retain momentum without accelerating")
	race.distance = 80
	for i in range(60): race.step(1.0/60,0,false,true,false)
	check(not race.drifting and race.drifts_completed > 0,"Settling the car on a straight must exit the drift")
	check(Contact.overlap(0,2.5,0,0).is_empty(),"Separated parallel cars must not collide")
	check(not Contact.overlap(0,2.5,0.55,0).is_empty(),"An angled drifting car must collide across its wider footprint")
	check(Contact.overlap(6,0,0,0).is_empty(),"Longitudinally separated cars must not collide")
	reset_drive(race)
	race.speed = 60
	race.lane = 0
	var other: Dictionary = race.rivals[0]
	# The Tour runs without CPU cars; switch one on to test the contact code itself.
	other.active = true
	other.car.visible = true
	other.distance = race.distance+3
	other.lane = 0
	other.target_lane = 0
	other.speed = 30
	race.step(1.0/60,0,false,true,false)
	check(race.traffic_hits == 1 and race.speed < 50,"Rear impact must lose speed and register contact")
	check(Contact.overlap(other.distance-race.distance,other.lane-race.lane,0,0).is_empty(),"Collision resolution must separate overlapping bodies")
	reset_drive(race)
	race.distance = 80
	race.speed = 70
	race.lane = 9.15
	race.step(0.1,1,false,true,false)
	check(race.wall_hits > 0 and race.impact > 0 and race.lane <= race.track.lane_limits(race.distance).y+0.01,"Roadside contact must align with the rail and produce impact")
	reset_drive(race)
	var length: float = race.track.length
	race.award_checkpoint()
	race.distance = length+Library.FORK_COMMIT-0.2
	race.speed = 45
	race.lane = 3.2
	var expected: Vector3 = race.track.point(race.distance+(45+22.0/60)/60,race.lane)
	race.step(1.0/60,0,false,true,false)
	check(race.stage_index == 1 and race.route_node == 1 and race.checkpoints == 1,"Taking the right fork must choose the right route node")
	check(race.time_left > Library.START_TIME+Library.checkpoint_bonus(1)-1,"Checkpoint must extend the countdown")
	check(race.track.point(race.distance,race.lane).distance_to(expected) < 0.3,"Changing road sections must not teleport the car")
	# A late switch must not duplicate or alter the completed checkpoint reward.
	var old_bonus: float = race.checkpoint_award
	race.distance = 100
	var f: Vector3 = (race.track.point(102)-race.track.point(100)).normalized()
	var across := Vector3(-f.z,0,f.x).normalized()
	race.lane = (race.track.sibling.point(100)-race.track.point(100)).dot(across)
	race.speed = 0
	race.lane_velocity = 0
	race.step(1.0/60,0,false,false,false)
	check(race.route_node == 0 and is_equal_approx(race.checkpoint_award,old_bonus),"Switching branches after a checkpoint must not change or duplicate its reward")
	for i in range(3):
		race.award_checkpoint()
		clear_traffic(race)
		race.distance = race.track.length+Library.FORK_COMMIT-0.1
		race.speed = 40
		race.step(1.0/60,0,false,true,false)
	check(race.stage_index == 4 and race.checkpoints == 4,"Tour must visit five stages through four checkpoints")
	race.distance = race.track.length-0.1
	race.speed = 40
	race.step(1.0/60,0,false,true,false)
	check(race.state == "finished","Final road endpoint must finish the tour without wrapping")
	reset_drive(race)
	race.time_left = 0.001
	race.step(1.0/60,0,false,false,false)
	check(race.state == "failed","Running out of time must end the tour")
	race.state = "racing"
	for viewport in [Vector2i(1280,720),Vector2i(2340,1080),Vector2i(390,844)]:
		root.size = viewport
		race.hud.fingers.clear()
		for action in ["gas","brake","nitro"]:
			var event := InputEventScreenTouch.new()
			event.index = {"gas":1,"brake":2,"nitro":3}[action]
			event.position = race.hud.buttons[action].get_center()*race.hud.ui_scale()+race.hud.ui_offset()
			event.pressed = true
			race.hud.handle_pointer(event)
		check(race.hud.held("gas") and race.hud.held("brake") and race.hud.held("nitro"),"Gas, brake and nitro touch targets must remain aligned on resize")
	root.size = Vector2i(1280,720)
	check(not race.hud.buttons.gas.intersects(race.hud.buttons.brake),"Gas and brake must have distinct touch targets")
	reset_drive(race)
	var minimum := INF
	var maximum := 0.0
	for i in range(100):
		var d: float = race.track.length*i/100
		minimum = minf(minimum,race.track.half_width(d))
		maximum = maxf(maximum,race.track.half_width(d))
	check(maximum-minimum > 2.5,"The same road must visibly widen and narrow")
	var mesh_arrays = race.track.road_surface.mesh.surface_get_arrays(0)
	for segment in [0,230,540,830]:
		var d: float = race.track.length*segment/900
		var edge: Vector3 = mesh_arrays[Mesh.ARRAY_VERTEX][segment*6]
		check(absf(edge.distance_to(race.track.point(d))-race.track.half_width(d)) < 0.02,"Rendered road edges must follow the same width as driving bounds")
	var start: Vector2 = race.hud.route_map_point(0,0)
	var left: Vector2 = race.hud.route_map_point(1,0)
	var right: Vector2 = race.hud.route_map_point(1,1)
	check(start.y > left.y and start.y > right.y and left.x < start.x and right.x > start.x,"Route map must travel upward with left/right matching the physical fork")
	check(not race.hud.buttons.nitro.intersects(race.hud.buttons.drift) and not race.hud.buttons.nitro.intersects(race.hud.buttons.gas),"Nitro must have its own visible touch target")
	race.speed = race.vehicle.max_speed
	race.nitro = 70
	for i in range(30): race.step(1.0/60,0,false,true,false,true)
	check(race.nitro_active and race.speed > race.vehicle.max_speed+8 and race.nitro < 63,"Nitro must accelerate beyond cruise speed and consume fuel")
	race.step(1.0/60,0,false,true,true,true)
	check(not race.nitro_active and race.braking,"Braking must override nitro")
	race.nitro = 0
	race.distance = 80
	race.step(1.0/60,0,false,true,false,true)
	check(not race.nitro_active and race.nitro_locked,"Empty nitro must lock out repeated tiny boost pulses")
	race.nitro = 20
	race.step(1.0/60,0,false,true,false,true)
	check(race.nitro_active,"Recharged nitro must become usable again")
	race.speed_ambience.update(race)
	check(not race.speed_ambience.petals.emitting,"Normal driving must not emit ambient particles")
	race.checkpoints = 1
	race.speed_ambience.update(race)
	check(race.speed_ambience.petals.one_shot,"Celebrations must be bounded one-shot bursts")
	var canopies := 0
	for stage in range(5):
		for node in range(stage+1):
			var span := Library.canopy_span(stage,node)
			if span.y > span.x: canopies += 1
	check(canopies <= 2 and Library.canopy_span(0,0) == Vector2.ZERO,"Glass roofs must be rare and absent from the starting coast")
	var city_tunnel := Library.tunnel_span(1,1)
	check(city_tunnel.y-city_tunnel.x >= 900,"There must be a genuinely long continuous city tunnel")
	var section = load("res://scripts/road_section.gd")
	var easy = section.new(Vector3.ZERO,-PI/2,4,0)
	var hard = section.new(Vector3.ZERO,-PI/2,4,4)
	var easy_width := 0.0
	var hard_width := 0.0
	var easy_bends := 0.0
	var hard_bends := 0.0
	for i in range(100):
		var t := 0.15+i*0.007
		easy_width += easy.half_width(easy.length*t)
		hard_width += hard.half_width(hard.length*t)
		easy_bends += absf(easy.curvature(easy.length*t))
		hard_bends += absf(hard.curvature(hard.length*t))
	check(hard.length > easy.length+500 and hard_width < easy_width-100 and hard_bends > easy_bends*1.25,"Right choices must produce longer, narrower and more demanding roads")
	easy.free()
	hard.free()
	race.track.reset(4,4)
	race.brain.stage_changed(race)
	var active_count := 0
	for r in race.rivals:
		if r.active: active_count += 1
	check(active_count == 16,"The hardest route must have denser active traffic")
	print("Tour checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await process_frame
	failures += await preload("res://tests/garage_checks.gd").new().run(self)
	failures += await preload("res://tests/modes_checks.gd").new().run(self)
	failures += await preload("res://tests/road_feature_checks.gd").new().run(self)
	failures += await preload("res://tests/traffic_checks.gd").new().run(self)
	failures += await preload("res://tests/drift_rpm_checks.gd").new().run(self)
	failures += await preload("res://tests/speedway_checks.gd").new().run(self)
	failures += await preload("res://tests/air_checks.gd").new().run(self)
	failures += await preload("res://tests/tunnel_lights_checks.gd").new().run(self)
	failures += await preload("res://tests/render_budget_checks.gd").new().run(self)
	failures += await preload("res://tests/fork_checks.gd").new().run(self)
	failures += await preload("res://tests/shoulder_checks.gd").new().run(self)
	failures += await preload("res://tests/review_regressions.gd").new().run(self)
	failures += await preload("res://tests/back_navigation_checks.gd").new().run(self)
	failures += await preload("res://tests/tunnel_render_checks.gd").new().run(self)
	failures += await preload("res://tests/scenery_3d_checks.gd").new().run(self)
	failures += await preload("res://tests/speedway_structure_checks.gd").new().run(self)
	failures += await preload("res://tests/collision_feedback_checks.gd").new().run(self)
	failures += await preload("res://tests/world_car_checks.gd").new().run(self)
	failures += await preload("res://tests/circuit_progress_checks.gd").new().run(self)
	failures += await preload("res://tests/fuji_geometry_checks.gd").new().run(self)
	failures += await preload("res://tests/fuji_world_checks.gd").new().run(self)
	failures += await preload("res://tests/world_rival_checks.gd").new().run(self)
	failures += await preload("res://tests/boost_lane_checks.gd").new().run(self)
	failures += await preload("res://tests/boost_feedback_checks.gd").new().run(self)
	failures += await preload("res://tests/vehicle_audio_checks.gd").new().run(self)
	failures += await preload("res://tests/gamepad_checks.gd").new().run(self)
	failures += await preload("res://tests/guardrail_checks.gd").new().run(self)
	failures += await preload("res://tests/road_width_checks.gd").new().run(self)
	failures += await preload("res://tests/loading_screen_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_gimmick_checks.gd").new().run(self)
	failures += await preload("res://tests/result_screen_checks.gd").new().run(self)
	failures += await preload("res://tests/juice_checks.gd").new().run(self)
	failures += await preload("res://tests/suncoast_world_checks.gd").new().run(self)
	failures += await preload("res://tests/midnight_checks.gd").new().run(self)
	failures += await preload("res://tests/corner_feel_checks.gd").new().run(self)
	failures += await preload("res://tests/tour_geometry_checks.gd").new().run(self)
	failures += await preload("res://tests/crash_recovery_checks.gd").new().run(self)
	failures += await preload("res://tests/recovery_ui_checks.gd").new().run(self)
	failures += await preload("res://tests/world_crash_checks.gd").new().run(self)
	failures += await preload("res://tests/fullscreen_checks.gd").new().run(self)
	failures += await preload("res://tests/resource_lifecycle_checks.gd").new().run(self)
	quit(1 if failures else 0)
