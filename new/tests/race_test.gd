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
	check(themes.size() == 8,"Route graph must contain all eight requested themes")
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
	check(race.wall_hits > 0 and race.impact > 0 and race.lane <= 9.2,"Roadside contact must align with the rail and produce impact")
	reset_drive(race)
	var length: float = race.track.length
	race.distance = length+Library.FORK_COMMIT-0.2
	race.speed = 45
	race.lane = 3.2
	var expected: Vector3 = race.track.point(race.distance+(45+22.0/60)/60,race.lane)
	race.step(1.0/60,0,false,true,false)
	check(race.stage_index == 1 and race.route_node == 1 and race.checkpoints == 1,"Taking the right fork must choose the right route node")
	check(race.time_left > Library.START_TIME+21,"Checkpoint must extend the countdown")
	check(race.track.point(race.distance,race.lane).distance_to(expected) < 0.3,"Changing road sections must not teleport the car")
	for i in range(3):
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
		for action in ["gas","brake"]:
			var event := InputEventScreenTouch.new()
			event.index = 1 if action == "gas" else 2
			event.position = race.hud.buttons[action].get_center()*race.hud.ui_scale()+race.hud.ui_offset()
			event.pressed = true
			race.hud.handle_pointer(event)
		check(race.hud.held("gas") and race.hud.held("brake"),"Gas and brake touch targets must remain aligned on resize")
	root.size = Vector2i(1280,720)
	check(not race.hud.buttons.gas.intersects(race.hud.buttons.brake),"Gas and brake must have distinct touch targets")
	print("Tour checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
