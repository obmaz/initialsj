extends RefCounted
# Suncoast uses real world bodies and colliders like Fuji. A drive around the whole banked oval
# proves the ground, walls, gates and lap counting work end to end.
const Crash = preload("res://tests/world_crash_checks.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",1)
	await tree.physics_frame
	var collision: Node3D = race.track.world_collision
	check(race.world_race != null and collision != null,"Suncoast needs a world controller and colliders")
	check(int(collision.get_meta("ground_triangles")) > 4000 and int(collision.get_meta("barrier_triangles")) > 10000,"The oval needs real road and wall triangles")
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
	check(race.laps_completed == 1,"A driven lap of the oval must be counted once (laps=%d at %.0f m)" % [race.laps_completed,race.distance])
	check(race.wall_hits-walls <= 1 and recoveries == 0,"A clean lap must not need rails or recovery (walls=%d)" % (race.wall_hits-walls))
	check(peak > 55,"The oval must allow high speed (peak %.0f)" % peak)
	check(race.state == "racing","One lap must not end a three-lap race")
	# A fast rail hit throws the car on the oval just like on Fuji.
	var crash := Crash.new()
	var hit: Dictionary = await crash.rail_impact(tree,race,72)
	check(bool(hit.contact.get("severe",false)) and bool(hit.triggered),"A fast rail hit on Suncoast must launch the car")
	failures += crash.failures
	race.queue_free()
	await tree.process_frame
	print("Suncoast real-body lap / walls / gates / rail launch: ","PASS" if failures == 0 else "FAIL")
	return failures
