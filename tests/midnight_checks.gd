extends RefCounted
# Midnight Harbor is a closed night circuit on real bodies. A driven lap proves the layout closes,
# the walls hold, the gates count, and the drift section really needs the brake-slide.
const Crash = preload("res://tests/world_crash_checks.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",2)
	await tree.physics_frame
	var collision: Node3D = race.track.world_collision
	check(race.world_race != null and collision != null,"Midnight Harbor needs a world controller and colliders")
	check(int(collision.get_meta("ground_triangles")) > 3000 and int(collision.get_meta("barrier_triangles")) > 8000,"The circuit needs real road and wall triangles")
	race.open_garage()
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	var body: CharacterBody3D = race.world_race.player_body
	var walls: int = race.wall_hits
	var recoveries := 0
	var target_lane := -2.5
	var peak := 0.0
	for frame in range(60*130):
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		var look := clampf(race.speed*0.65,14,46)
		var to: Vector3 = race.track.point(race.distance+look,target_lane)-body.feet_position()
		var angle := atan2(to.dot(right),to.dot(forward))
		var wheel: float = (0.46+race.vehicle.handling*0.007)/(1+race.speed*0.035)*race.world_race.WorldCar.steering_scale(race.speed)
		var axis := clampf(atan(5.4*sin(angle)/look)/wheel,-1,1)
		var safe: float = race.vehicle.max_speed
		for ahead in [0.0,25.0,55.0,95.0,145.0]:
			var radius_speed: float = sqrt(race.vehicle.grip*0.72/maxf(absf(race.track.curvature(race.distance+ahead)),0.0001))
			safe = minf(safe,sqrt(radius_speed*radius_speed+2*25*ahead))
		await tree.physics_frame
		race.step(1.0/60,axis,false,true,race.speed > safe+0.5)
		peak = maxf(peak,race.speed)
		if race.return_flash > 0: recoveries += 1
		if race.laps_completed >= 1: break
	check(race.laps_completed == 1,"A driven lap of the circuit must be counted once (laps=%d at %.0f m)" % [race.laps_completed,race.distance])
	check(race.wall_hits-walls <= 1 and recoveries == 0,"A clean lap must not need rails or recovery (walls=%d)" % (race.wall_hits-walls))
	check(peak > 45,"The circuit must allow speed on the straights (peak %.0f)" % peak)
	var section: Node3D = race.track.active
	check(race.track.course_id == 2 and section.course_id == 2 and section.closed_loop,"Midnight Harbor must be the third closed circuit")
	var tight := 0
	var previous := 0.0
	for d in range(0,int(section.length),10):
		var bend: float = absf(race.track.curvature(float(d)))
		if bend > 0.0125 and previous <= 0.0125: tight += 1
		previous = bend
	check(tight >= 5,"The night circuit needs at least five drift bends (found %d)" % tight)
	var narrow := 99.0
	var wide := 0.0
	for d in range(0,int(section.length),10):
		narrow = minf(narrow,section.half_width(float(d)))
		wide = maxf(wide,section.half_width(float(d)))
	check(narrow >= 6.5 and wide-narrow >= 1.0,"The width must vary but stay driveable (%.1f-%.1f)" % [narrow,wide])
	check(race.track.ground_plane != null and race.track.ground_plane.position.y > 0,"The night harbour needs its raised ground")
	check(race.state == "racing","One lap must not end a three-lap race")
	# A fast rail hit throws the car on the circuit just like on Fuji.
	var crash := Crash.new()
	var hit: Dictionary = await crash.rail_impact(tree,race,72)
	check(bool(hit.contact.get("severe",false)) and bool(hit.triggered),"A fast rail hit on Midnight Harbor must launch the car")
	failures += crash.failures
	race.queue_free()
	await tree.process_frame
	print("Midnight Harbor real-body lap / drift bends / widths / walls / rail launch: ","PASS" if failures == 0 else "FAIL")
	return failures
