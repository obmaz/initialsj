extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)

func clearance(a: CharacterBody3D, b: CharacterBody3D) -> float:
	# Horizontal OBB separating axes use the motor's real 2.1 x 4.3 m chassis.
	# Negative clearance on every axis is physical overlap, including yaw.
	if absf(a.position.y-b.position.y) > 1.3: return INF
	var separation := -INF
	for direction in [a.global_basis.x,a.global_basis.z,b.global_basis.x,b.global_basis.z]:
		var axis := Vector3(direction.x,0,direction.z).normalized()
		var radius_a: float = absf(axis.dot(a.global_basis.x))*1.05+absf(axis.dot(a.global_basis.z))*2.15
		var radius_b: float = absf(axis.dot(b.global_basis.x))*1.05+absf(axis.dot(b.global_basis.z))*2.15
		separation = maxf(separation,absf((b.position-a.position).dot(axis))-radius_a-radius_b)
	return separation

func arrange(tree: SceneTree, race: Node3D, player_d: float = 630, rival_d: float = 602) -> void:
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	race.step(1.0/60,0,false,false,false)
	race.rivals[0].active = true
	race.rivals[0].pace = 70
	race.world_race.teleport(0,player_d,2.4)
	race.world_race.teleport(1,rival_d,2.4)
	await tree.physics_frame
	await tree.physics_frame

func parked_pass(tree: SceneTree, race: Node3D, side_blocker: bool = false) -> Dictionary:
	await arrange(tree,race)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.bodies[1]
	if side_blocker:
		race.rivals[1].active = true
		race.rivals[1].pace = 0
		session.teleport(2,605,6.3)
	body.velocity = body.forward_direction()*40
	var minimum := INF
	var first_target := 0.0
	var passed_at := 0
	for frame in range(600):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
		minimum = minf(minimum,clearance(body,session.player_body))
		if side_blocker: minimum = minf(minimum,clearance(body,session.bodies[2]))
		if frame == 0: first_target = race.rivals[0].target_lane
		if race.rivals[0].distance > race.distance+10:
			passed_at = frame+1
			break
	check(passed_at > 0,"Every world vehicle must physically pass a parked leader on the clear part of the road")
	check(minimum > -0.035,"CPU overtaking and lane changes must not overlap actual chassis footprints")
	check(absf(race.rivals[0].lane) < race.track.half_width(race.rivals[0].distance)-1,"CPU passing targets must leave a real margin inside the road edge")
	if side_blocker: check(first_target < 1.4,"A car alongside the right passing lane must make the CPU choose the clear left side")
	return {"vehicle":race.vehicle.id,"side_blocker":side_blocker,"pass_frames":passed_at,"minimum_obb_clearance_m":minimum,"first_target_lane":first_target,"final_distance_m":race.rivals[0].distance}

func reverse_recovery(tree: SceneTree, race: Node3D) -> Dictionary:
	await arrange(tree,race,630,624.5)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.bodies[1]
	var original: Vector3 = body.feet_position()
	var minimum := INF
	var backed := 0.0
	var reverse_frames := 0
	var passed := false
	for frame in range(900):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
		minimum = minf(minimum,clearance(body,session.player_body))
		backed = maxf(backed,(original-body.feet_position()).dot(body.forward_direction()))
		if float(race.rivals[0].world_reverse) > 0: reverse_frames += 1
		if race.rivals[0].distance > race.distance+10:
			passed = true
			break
	check(reverse_frames > 0 and reverse_frames <= 62 and backed > 2,"A nose-blocked CPU must create turning space through one bounded physical reverse manoeuvre")
	check(passed and minimum > -0.035,"The reversed CPU must drive around the leader without a teleport or chassis overlap")
	# Restart clears transient manoeuvres even though rival dictionaries persist.
	race.rivals[0].world_reverse = 0.8
	race.rivals[0].world_reverse_axis = 0.65
	race.rivals[0].world_reverse_cooldown = 3
	race.rivals[0].world_stuck = 1
	race.restart()
	check(race.rivals[0].world_reverse == 0 and race.rivals[0].world_reverse_axis == 0 and race.rivals[0].world_reverse_cooldown == 0 and race.rivals[0].world_stuck == 0,"Retry must clear every CPU recovery timer and steering input")
	return {"reverse_frames":reverse_frames,"backed_m":backed,"passed":passed,"minimum_obb_clearance_m":minimum}

func rear_and_deck_checks(tree: SceneTree, race: Node3D) -> void:
	await arrange(tree,race,630,624.5)
	var session: Node3D = race.world_race
	race.rivals[1].active = true
	race.rivals[1].pace = 0
	session.teleport(2,618,2.4)
	await tree.physics_frame
	check(not session.rival_rear_clear(1),"A real nearby car behind the CPU must block reversing into that space")
	var minimum := INF
	var unsafe_reverse := false
	for frame in range(150):
		await tree.physics_frame
		var rear_blocked: bool = not session.rival_rear_clear(1)
		race.step(1.0/60,0,false,false,false)
		minimum = minf(minimum,clearance(session.bodies[1],session.bodies[2]))
		if rear_blocked and float(race.rivals[0].world_reverse) > 0: unsafe_reverse = true
	check(not unsafe_reverse,"The CPU must never start or continue reversing while another car occupies its rear clearance")
	check(minimum > -0.035,"A blocked-rear CPU must not push into the following car")
	race.rivals[1].active = false
	var upper: float = race.track.active.bridge_upper_distance
	var lower: float = race.track.active.bridge_lower_distance
	session.teleport(0,lower,2.4)
	session.teleport(1,upper,2.4)
	await tree.physics_frame
	check(absf(session.bodies[1].position.y-session.player_body.position.y) > 25,"The avoidance fixture must use genuinely separate overpass decks")
	race.rivals[0].decision = 0
	var selected: float = session.rival_lane(1,upper,20,1.0/60)
	check(absf(selected-2.4) < 0.01 and session.rival_rear_clear(1),"Traffic below a bridge must not force lane avoidance or block physical reverse on the upper deck")

# Rivals far from the player are cheaper to simulate; the hand-over must be seamless.
func rival_detail_levels(tree: SceneTree, race: Node3D) -> void:
	race.restart()
	race.state = "racing"
	var world: Node3D = race.world_race
	var player: CharacterBody3D = world.player_body
	for rival in race.rivals: rival.active = false
	race.rivals[0].active = true
	var body: CharacterBody3D = world.bodies[1]
	var d: float = world.safe_distance+400.0
	for case in [[20.0,1],[100.0,2],[400.0,0]]:
		world.teleport(1,world.safe_distance+case[0],0.0,true)
		body.velocity = body.forward_direction()*30
		check(world.rival_stride(body) == case[1],"A rival %.0f m from the player must use detail level %d" % [case[0],case[1]])
	# A carried rival keeps moving along the road, in its lane, without a body sweep.
	world.teleport(1,world.safe_distance+400.0,2.0,true)
	body.velocity = body.forward_direction()*40
	var start_distance: float = world.trackers[1].distance
	for frame in range(60): world.update_rivals(1.0/60)
	var moved: float = world.trackers[1].distance-start_distance
	check(moved > 20 and moved < 60,"A carried rival must keep driving along the road (moved %.1f m)" % moved)
	check(race.rivals[0].speed > 5 and absf(race.rivals[0].lane) < race.track.half_width(race.rivals[0].distance),"A carried rival must stay on the road at speed")
	# Handing a carried rival back to the physics body must not jump it.
	var before: Vector3 = body.global_position
	var along: Vector3 = body.forward_direction()
	world.teleport(0,world.trackers[1].distance-80.0,0.0,false)
	player.velocity = Vector3.ZERO
	for frame in range(30): world.update_rivals(1.0/60)
	var jump: float = body.global_position.distance_to(before)
	check(jump < 60.0 and world.rival_stride(body) < 3,"A rival that comes back into range must hand over smoothly (moved %.1f m)" % jump)

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",0)
	await tree.physics_frame
	await tree.physics_frame
	var passes := []
	for choice in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(choice)
		passes.append(await parked_pass(tree,race))
	passes.append(await parked_pass(tree,race,true))
	var reverse := await reverse_recovery(tree,race)
	await rear_and_deck_checks(tree,race)
	await rival_detail_levels(tree,race)
	FileAccess.open(Report.path("world-rival-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"passes":passes,"reverse":reverse},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("World rivals / physical passing / occupied lane / bounded reverse / rear clearance / bridge decks: ","PASS" if failures == 0 else "FAIL")
	return failures
