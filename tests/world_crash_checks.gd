extends RefCounted
const Report = preload("res://tests/report.gd")
const Drive = preload("res://tests/fuji_world_checks.gd")
var failures := 0
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)

func quiet(tree: SceneTree, race: Node3D) -> void:
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	race.step(1.0/60,0,false,false,false)
	await tree.physics_frame

func rail_impact(tree: SceneTree, race: Node3D, speed: float, glancing: bool = false, preserve_progress: bool = false) -> Dictionary:
	if not preserve_progress: race.restart()
	await quiet(tree,race)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var d: float = session.safe_distance if preserve_progress else race.track.length*0.03
	var right: Vector3 = (race.track.point(d,1)-race.track.point(d,-1)).normalized()
	var up: Vector3 = session.road_up(d)
	var forward: Vector3 = (race.track.point(d+2)-race.track.point(d-2)).normalized()
	var lane: float = race.track.half_width(d)+race.track.active.rail_setback(d,1)-4.5
	session.teleport(0,d,lane,not preserve_progress)
	var direction := right
	if glancing: direction = (forward*sqrt(speed*speed-144)+right*12).normalized()
	body.reset_pose(body.feet_position(),direction,up)
	await tree.physics_frame
	body.velocity = direction*speed
	race.speed = session.speed_of(body)
	var score: float = race.score
	var first := {}
	var peak: float = body.feet_position().y
	var base: float = peak
	var roll := 0.0
	var airborne_frames := 0
	var triggered := false
	var away_speed := 0.0
	var launch_speed := 0.0
	for frame in range(300 if glancing else 160):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
		for hit in body.last_contacts:
			if first.is_empty() and hit.collider is StaticBody3D and hit.collider.get_collision_layer_value(2):
				first = {"incoming_speed":hit.incoming_speed,"closing_speed":hit.closing_speed,"severe":hit.severe}
				away_speed = body.velocity.dot(hit.normal)
				launch_speed = body.velocity.y
		triggered = triggered or race.crash.active
		roll = maxf(roll,absf(race.crash.visual_roll))
		peak = maxf(peak,body.feet_position().y)
		if not body.grounded: airborne_frames += 1
		if not first.is_empty() and speed < 55.5: break
	check(not first.is_empty(),"The crash fixture must hit Fuji's actual outer guardrail collider")
	if speed >= 55.5:
		check(triggered and first.severe,"A severe high-speed real guardrail hit must start the tumble state")
		check(launch_speed > 7 and away_speed > 6 and peak-base > 1.5 and airborne_frames > 25,"The chassis must physically rebound and fly above the road under gravity")
		check(roll > PI and not race.crash.active,"The visual tumble must complete a full roll and settle without rolling the collider")
		var travel: Vector3 = Vector3(body.velocity.x,0,body.velocity.z)
		var nose: Vector3 = body.forward_direction()
		nose.y = 0
		if travel.length() > 5: check(absf(nose.normalized().signed_angle_to(travel.normalized(),Vector3.UP)) < 0.35,"A thrown car must land facing the way it travels")
		check(body.global_basis.y.dot(Vector3.UP) > 0.9,"The upright motor collider must retain reliable road contacts throughout visual tumbling")
		check(race.score == score,"A crash landing must not award a successful jump bonus")
	else:
		check(not triggered and not first.severe,"A rail hit below the launch speed must bounce without a crash launch")
		check(away_speed < 4.0,"A hit below the launch speed must not bounce the car back off the rail")
	return {"vehicle":race.vehicle.id,"entry_mps":speed,"glancing":glancing,"contact":first,"triggered":triggered,"rebound_mps":away_speed,"launch_mps":launch_speed,"height_gain_m":peak-base,"airborne_frames":airborne_frames,"maximum_roll":roll}

func traffic_and_floor(tree: SceneTree, race: Node3D) -> void:
	race.restart()
	await quiet(tree,race)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	race.rivals[0].active = true
	race.rivals[0].pace = 0
	session.teleport(0,350,0)
	session.teleport(1,364,0)
	await tree.physics_frame
	body.velocity = body.forward_direction()*80
	race.speed = 80
	var actual_contact := false
	var flipped := false
	for frame in range(24):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
		for hit in body.last_contacts:
			if hit.collider == session.bodies[1]: actual_contact = true
		flipped = flipped or race.crash.active
	check(actual_contact and not flipped,"A real high-speed car contact must rebound without being mistaken for a guardrail launch")
	race.restart()
	await quiet(tree,race)
	session.teleport(0,350,0)
	await tree.physics_frame
	body.velocity = body.forward_direction()*80
	race.speed = 80
	for frame in range(30):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
	check(body.grounded and not race.crash.active and race.wall_hits == 0,"Fast travel across the real road floor must never trigger a barrier tumble")

func earned_progress(tree: SceneTree, race: Node3D) -> Dictionary:
	race.restart()
	await quiet(tree,race)
	var driver := Drive.new()
	var session: Node3D = race.world_race
	var tracker: RefCounted = session.trackers[0]
	for gate in range(13):
		var at: float = tracker.next_gate-6
		session.teleport(0,at,0,false)
		await tree.physics_frame
		driver.seed_speed(race,20)
		for frame in range(42): await driver.tick(tree,race,0,false)
		check(tracker.gates_passed == gate+1,"Recovery bookkeeping must be tested with actually crossed ordered gates")
	check(tracker.laps == 1 and race.laps_completed == 1,"The recovery fixture must earn one real lap before crashing")
	return {"gates":tracker.gates_passed,"laps":tracker.laps,"next_gate":tracker.next_gate}

func manual_recovery(tree: SceneTree, race: Node3D) -> Dictionary:
	var earned := await earned_progress(tree,race)
	var crash_metrics := await rail_impact(tree,race,72,false,true)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var tracker: RefCounted = session.trackers[0]
	var d: float = session.safe_distance
	var lane: float = session.safe_lane
	# A real stationary opponent occupies the preferred safe landing point.
	race.rivals[0].active = true
	race.rivals[0].pace = 0
	session.teleport(1,d,lane)
	session.bodies[1].collision_layer = 4
	session.bodies[1].collision_mask = 7
	var parked_lane: float = race.track.half_width(d)+2
	var up: Vector3 = session.road_up(d)
	var forward: Vector3 = race.track.point(d+2)-race.track.point(d-2)
	body.reset_pose(race.track.point(d,parked_lane)+up*0.04,forward,up)
	race.speed = 0
	race.air.reset()
	tracker.reposition(d)
	tracker.lane = parked_lane
	race.recovery.reset(body.feet_position())
	for frame in range(239):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
	check(not race.recovery_available,"A recovery button must wait for four seconds of insufficient movement")
	var stuck_at: Vector3 = body.feet_position()
	race.recover_car()
	check(body.feet_position().distance_to(stuck_at) < 0.01,"An unavailable recovery action must not move the physical car")
	for frame in range(3):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
	check(race.recovery_available,"Staying within the stuck movement window must expose manual recovery")
	race.recover_car()
	check(not race.recovery_available and body.velocity.is_zero_approx() and not race.crash.active,"Explicit recovery must reset motion, tumble and its button state")
	check(absf(race.lane) < race.track.half_width(race.distance)-1 and body.position.distance_to(session.bodies[1].position) > 2.2,"Recovery must choose an unoccupied lane inside the real road")
	check(tracker.gates_passed == earned.gates and tracker.laps == earned.laps and tracker.next_gate == earned.next_gate and race.laps_completed == earned.laps,"Crash and manual recovery must preserve every earned lap and ordered gate")
	check(race.camera.position.distance_to(race.player.position) < 12,"Recovery must reset the chase camera at the rescued physical car")
	# A blocked safe region is refused, rather than placing a chassis in a wall.
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,10,100)
	shape.shape = box
	wall.add_child(shape)
	tree.root.add_child(wall)
	wall.position = race.track.point(d)+Vector3.UP*3
	await tree.physics_frame
	var before := body.global_transform
	check(not session.recover_player() and body.global_transform.is_equal_approx(before),"Recovery must leave the player untouched when every safe destination is obstructed")
	wall.queue_free()
	return {"earned":earned,"crash":crash_metrics,"recovery_lane":race.lane,"recovery_distance":race.distance,"rival_separation_m":body.position.distance_to(session.bodies[1].position)}

func tunnel_camera(tree: SceneTree, race: Node3D) -> void:
	race.restart()
	await quiet(tree,race)
	var session: Node3D = race.world_race
	var d: float = race.track.active.underpass_span().x+124
	session.teleport(0,d,0)
	var up: Vector3 = session.road_up(d)
	var forward: Vector3 = race.track.point(d+2)-race.track.point(d-2)
	var base: Vector3 = race.track.point(d)
	session.player_body.reset_pose(base+Vector3.UP*3.6,forward,up)
	race.crash.start(72,Vector2(1,0),base.y)
	race.place_cars()
	await tree.physics_frame
	var query := PhysicsRayQueryParameters3D.create(base+Vector3.UP*4.5,base+Vector3.UP*8,2)
	var roof := race.get_world_3d().direct_space_state.intersect_ray(query)
	check(not roof.is_empty(),"The camera fixture must use the real Fuji underpass roof collider")
	session.update_camera(1)
	if not roof.is_empty():
		check(race.camera.position.y < roof.position.y-0.1,"The crash chase camera must remain beneath the actual tunnel roof")
	check(race.camera.position.distance_to(race.player.position) > 1,"A blocked crash camera must retain usable distance from the car")

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",0)
	await tree.physics_frame
	await tree.physics_frame
	var impacts := []
	for choice in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(choice)
		impacts.append(await rail_impact(tree,race,72))
	impacts.append(await rail_impact(tree,race,40))
	impacts.append(await rail_impact(tree,race,80,true))
	await traffic_and_floor(tree,race)
	var recovery := await manual_recovery(tree,race)
	await tunnel_camera(tree,race)
	race.queue_free()
	await tree.process_frame
	FileAccess.open(Report.path("world-crash-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"impacts":impacts,"recovery":recovery},"\t")+"\n")
	print("World crash / severe rail launch / ballistic tumble / safe manual recovery / preserved gates: ","PASS" if failures == 0 else "FAIL")
	return failures
