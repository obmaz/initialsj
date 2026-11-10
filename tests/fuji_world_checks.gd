extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func pilot_axis(race: Node3D, target_lane: float) -> float:
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var speed: float = session.speed_of(body)
	var look := clampf(speed*0.65,16,44)
	var target: Vector3 = race.track.point(session.trackers[0].distance+look,target_lane)
	var direction: Vector3 = target-body.feet_position()
	var forward: Vector3 = body.forward_direction()
	var right := Vector3(-forward.z,0,forward.x).normalized()
	var angle := atan2(direction.dot(right),direction.dot(forward))
	var wheel: float = (0.46+race.vehicle.handling*0.007)/(1+speed*0.035)*session.WorldCar.steering_scale(speed)
	return clampf(atan(5.4*sin(angle)/look)/wheel,-1,1)
func seed_speed(race: Node3D, speed: float) -> void:
	# Seed a real physical velocity, then synchronize the acceleration input.
	# Road distance/lane are never used to move the chassis during driving.
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction()*speed
	race.speed = race.world_race.speed_of(body)
func tick(tree: SceneTree, race: Node3D, lane: float, gas: bool = true) -> void:
	await tree.physics_frame
	race.step(1.0/60,pilot_axis(race,lane),false,gas,false)
func quiet_race(tree: SceneTree, race: Node3D) -> void:
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	# Let the session disable the old grid colliders before a new fixture.
	await tick(tree,race,0,false)
	await tree.physics_frame
func shoulder_regressions(tree: SceneTree, race: Node3D) -> Array:
	var rows := []
	var at: float = race.track.length*0.09
	for choice in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(choice)
		race.restart()
		await quiet_race(tree,race)
		var session: Node3D = race.world_race
		var body: CharacterBody3D = session.player_body
		session.teleport(0,at,0)
		await tree.physics_frame
		seed_speed(race,65)
		for frame in range(120): await tick(tree,race,0)
		var asphalt: float = session.speed_of(body)
		race.restart()
		await quiet_race(tree,race)
		var shoulder_lane: float = race.track.half_width(at)+2.2
		session.teleport(0,at,shoulder_lane)
		await tree.physics_frame
		seed_speed(race,65)
		for frame in range(120): await tick(tree,race,shoulder_lane)
		var dirt: float = session.speed_of(body)
		check(body.grounded and race.offroad_amount > 0.9 and race.wall_hits == 0,"Every Fuji vehicle must drive on real dirt runoff before reaching the set-back barrier")
		check(dirt < asphalt*0.78,"Fuji dirt must reduce the actual world speed for every vehicle")
		var return_frames := 0
		# Rejoin physically, then regain speed with the reduced engine force.
		for frame in range(240):
			await tick(tree,race,0)
			return_frames += 1
			if race.offroad_amount < 0.05 and session.speed_of(body) > dirt+10: break
		var returned: float = session.speed_of(body)
		var return_offroad: float = race.offroad_amount
		var return_walls: int = race.wall_hits
		var return_lane: float = session.trackers[0].lane
		check(race.offroad_amount < 0.05 and returned > dirt+10 and race.wall_hits == 0,"Rejoining Fuji asphalt must regain at least 36 km/h within four seconds without a rail hit")
		# Face the real outer rail. The body must sweep into its collider rather
		# than treating the asphalt edge as a wall or allowing the rail to tunnel.
		race.restart()
		await quiet_race(tree,race)
		session.teleport(0,at,shoulder_lane)
		var up: Vector3 = session.road_up(at)
		var outward: Vector3 = (race.track.point(at,1)-race.track.point(at,-1)).normalized().slide(up).normalized()
		body.reset_pose(body.feet_position(),outward,up)
		await tree.physics_frame
		seed_speed(race,35)
		var physical_wall := false
		var rail_impact := 0.0
		for frame in range(24):
			await tree.physics_frame
			race.step(1.0/60,0,false,true,false)
			rail_impact = maxf(rail_impact,race.impact)
			for hit in body.last_contacts:
				if hit.collider is StaticBody3D and hit.collider.name == "BarrierBody": physical_wall = true
		var lane: float = session.trackers[0].lane
		var rail: float = race.track.half_width(session.trackers[0].distance)+race.track.active.rail_setback(session.trackers[0].distance,1)
		check(physical_wall and race.wall_hits > 0 and rail_impact > 0,"Fuji's visible outer guardrail must produce a real physical impact for every vehicle")
		check(lane < rail-0.7,"The car footprint must remain inside the actual outer rail after collision")
		rows.append({"vehicle":race.vehicle.id,"asphalt_mps":asphalt,"dirt_mps":dirt,"returned_mps":returned,"return_frames":return_frames,"return_lane":return_lane,"return_offroad":return_offroad,"return_wall_hits":return_walls,"rail_peak_impact":rail_impact,"rail_hits":race.wall_hits,"physical_rail_contact":physical_wall})
	return rows
func traffic_regression(tree: SceneTree, race: Node3D) -> Dictionary:
	race.restart()
	await quiet_race(tree,race)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var rival: CharacterBody3D = session.bodies[1]
	race.rivals[0].active = true
	race.rivals[0].pace = 0
	session.teleport(0,350,0)
	session.teleport(1,364,0)
	# Activate the opposing collider before starting the swept approach.
	await tick(tree,race,0,false)
	await tree.physics_frame
	seed_speed(race,65)
	var physical_contact := false
	var closing_speed := 0.0
	for frame in range(24):
		await tick(tree,race,0)
		for hit in body.last_contacts:
			if hit.collider == rival:
				physical_contact = true
				closing_speed = maxf(closing_speed,float(hit.speed))
	check(physical_contact and closing_speed > 20 and race.traffic_hits > 0,"A player approach must collide with the rival's actual moving body and register traffic impact")
	var separation := body.position.distance_to(rival.position)
	check(separation > 4.1 and session.speed_of(body) < 20,"The real rival body must block the swept car without persistent body overlap")
	return {"physical_car_contact":physical_contact,"closing_speed_mps":closing_speed,"separation_m":separation,"traffic_hits":race.traffic_hits}
func pass_regression(tree: SceneTree, race: Node3D) -> Dictionary:
	race.restart()
	await quiet_race(tree,race)
	var session: Node3D = race.world_race
	race.rivals[0].active = true
	var old_gaps: Array[float] = []
	old_gaps.resize(7)
	old_gaps.fill(0.0)
	old_gaps[0] = 4.0
	session.teleport(0,352,0)
	session.teleport(1,350,3.0)
	await tree.physics_frame
	seed_speed(race,50)
	var energy: float = race.nitro
	session.update_passes(old_gaps,348)
	check(race.overtakes == 1 and race.near_misses == 1 and race.overtake_flash > 0 and race.near_miss_flash > 0 and race.nitro > energy,"A close physical same-deck pass must restore overtake and near-miss rewards")
	var lower: float = race.track.active.bridge_lower_distance
	var upper: float = race.track.active.bridge_upper_distance
	session.teleport(0,lower,0)
	session.teleport(1,upper,0)
	# Choose the orientation whose wrapped progress gap would otherwise count
	# as a pass. The actual world bodies remain separated by the bridge deck.
	if race.relative_gap(race.rivals[0].distance,race.distance) > 0:
		session.teleport(0,upper,0)
		session.teleport(1,lower,0)
	await tree.physics_frame
	seed_speed(race,50)
	var vertical: float = absf(session.player_body.position.y-session.bodies[1].position.y)
	session.update_passes(old_gaps,race.distance-2)
	check(vertical > 25 and race.overtakes == 1 and race.near_misses == 1,"Crossing the same X/Z on different Fuji bridge decks must never award a pass")
	return {"near_misses":race.near_misses,"overtakes":race.overtakes,"other_deck_separation_m":vertical}
func recovery_regression(tree: SceneTree, race: Node3D) -> Dictionary:
	race.restart()
	await quiet_race(tree,race)
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	var tracker: RefCounted = session.trackers[0]
	# Each gate is crossed by a physical driving step. Explicit positioning
	# between cases isolates rescue bookkeeping without replaying a full lap.
	for gate in range(13):
		var next: float = tracker.next_gate
		session.teleport(0,next-6,0,false)
		await tree.physics_frame
		seed_speed(race,20)
		for frame in range(42): await tick(tree,race,0,false)
		check(tracker.gates_passed == gate+1,"Real forward world motion must cross the selected Fuji gate exactly once")
	check(tracker.laps == 1 and race.laps_completed == 1,"The recovery fixture must begin after an actually crossed lap gate")
	var gates: int = tracker.gates_passed
	var laps: int = tracker.laps
	var next: float = tracker.next_gate
	var safe: float = session.safe_distance
	var safe_lane: float = session.safe_lane
	var safe_point: Vector3 = race.track.point(safe,safe_lane)
	body.reset_pose(safe_point-Vector3.UP*35,body.forward_direction(),Vector3.UP)
	await tree.physics_frame
	var lowest: float = body.feet_position().y
	for frame in range(58):
		await tick(tree,race,0,false)
		lowest = minf(lowest,body.feet_position().y)
	check(body.grounded and body.feet_position().distance_to(safe_point) < 0.3,"A truly fallen world car must recover onto its last safe physical road position")
	check(tracker.gates_passed == gates and tracker.laps == laps and tracker.next_gate == next and race.laps_completed == laps,"Physical fall recovery must preserve lap and gate progress without awarding an extra gate")
	return {"gates_preserved":gates,"laps_preserved":laps,"recovered_distance":tracker.distance,"safe_distance":safe,"lowest_y":lowest}
func ramp_regressions(tree: SceneTree, race: Node3D) -> Array:
	var rows := []
	var ramps: Array = race.track.active.features.filter(func(f): return f.kind == "ramp")
	for choice in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(choice)
		for ramp in ramps:
			race.restart()
			await quiet_race(tree,race)
			var session: Node3D = race.world_race
			var body: CharacterBody3D = session.player_body
			var lead_pad: Dictionary = race.track.active.features.filter(func(f): return f.kind == "boost" and f.distance < ramp.distance and ramp.distance-f.distance < 120 and absf(f.lane-ramp.lane) < 1)[0]
			session.teleport(0,lead_pad.distance-35,ramp.lane)
			await tree.physics_frame
			seed_speed(race,race.vehicle.max_speed)
			var peak := 0.0
			var air_frames := 0
			var landed := false
			var edge: float = ramp.distance+ramp.length*0.5
			for frame in range(200):
				await tick(tree,race,ramp.lane)
				peak = maxf(peak,race.air.height)
				if race.distance > edge-1 and not body.grounded: air_frames += 1
				if air_frames > 3 and body.grounded and race.distance > edge+5:
					landed = true
					break
			check(air_frames > 3 and peak > float(ramp.height)+0.08,"Every vehicle must physically launch from every Fuji ramp at boosted speed")
			check(race.surface.boosts_hit == 1,"Each jump approach must activate its real preceding pad through ground contact")
			check(landed and race.wall_hits == 0 and race.speed > 20,"%s / ramp %dm: each boosted jump must land without a rail or roof impact (walls=%d, speed=%.1f, landed=%s)" % [race.vehicle.id,ramp.distance,race.wall_hits,race.speed,landed])
			if ramp.distance < race.track.active.underpass_span().x and ramp.distance > 2000:
				check(race.distance < race.track.active.underpass_span().x-30,"The cutting jump must land before entering the tunnel")
			rows.append({"vehicle":race.vehicle.id,"pad_m":lead_pad.distance,"ramp_m":ramp.distance,"peak_height_m":peak,"air_frames":air_frames,"landed":landed,"landing_distance_m":race.distance,"wall_hits":race.wall_hits,"pads_hit":race.surface.boosts_hit})
	return rows

func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",0)
	await tree.physics_frame
	await tree.physics_frame
	check(race.world_race != null and race.track.world_collision != null,"Fuji must use real world bodies and track collision meshes")
	var session: Node3D = race.world_race
	var body: CharacterBody3D = session.player_body
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	for frame in range(90):
		await tree.physics_frame
		race.step(1.0/60,0,false,true,false)
	check(race.speed > 22 and race.speed < 26 and body.grounded,"The real car must use reduced launch acceleration on the actual road collider")
	var position: Vector3 = body.feet_position()
	race.distance += 300
	race.lane = 6
	race.place_cars()
	check(body.feet_position().distance_to(position) < 0.001 and race.player.position.distance_to(position) < 0.2,"Editing road telemetry must never move or snap a world-space car")
	race.distance = session.trackers[0].distance
	race.lane = session.trackers[0].lane
	var start_heading: Vector3 = body.forward_direction()
	for frame in range(24):
		await tree.physics_frame
		race.step(1.0/60,0.28,false,true,false)
	check(body.forward_direction().dot(start_heading) < 0.995,"Steering must turn the chassis in world space")
	# Park explicitly on both physical decks, not at an analytically selected height.
	var heights := []
	for d in [race.track.active.bridge_lower_distance,race.track.active.bridge_upper_distance]:
		session.teleport(0,d,0)
		for frame in range(8):
			await tree.physics_frame
			race.step(1.0/60,0,false,false,false)
		check(body.grounded and absf(body.feet_position().y-race.track.point(d).y) < 0.2,"The car must settle on the correct physical deck at a shared X/Z crossing")
		heights.append(body.feet_position().y)
	check(heights[1]-heights[0] > 25,"The upper car position must stay genuinely above the lower road")
	session.teleport(0,350,0)
	for frame in range(2): await tree.physics_frame
	race.speed = 0
	race.pause_tour()
	var paused: Vector3 = body.position
	for frame in range(4): await tree.physics_frame
	check(body.position.is_equal_approx(paused),"Pausing must stop world physics without drifting off the road")
	race.resume_tour()
	for frame in range(60):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,true)
	check(session.reversing and body.velocity.dot(body.forward_direction()) < -5,"Holding the existing brake at rest must allow mobile reverse recovery")
	for frame in range(30):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,true)
	check(session.wrong_way_time > 0.65,"Driving backwards along the circuit must show wrong-way feedback even when the chassis faces forward")
	var shoulders := await shoulder_regressions(tree,race)
	var traffic := await traffic_regression(tree,race)
	var passes := await pass_regression(tree,race)
	var recovery := await recovery_regression(tree,race)
	var ramps := await ramp_regressions(tree,race)
	# Both circuits use real bodies; the Tour keeps its own road-space controller.
	race.choose_mode("track",1)
	check(race.world_race != null and race.track.world_collision != null,"Suncoast must use real world bodies and colliders like Fuji")
	race.choose_mode("tour")
	check(race.world_race != null and not race.track.active.closed_loop,"투어도 실제 3D 차체로 분기 도로를 주행해야 한다")
	FileAccess.open(Report.path("fuji-world-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"crossing_car_heights_m":heights,"failures":failures,"world_telemetry_does_not_move_car":true,"shoulders":shoulders,"traffic":traffic,"passes":passes,"recovery":recovery,"ramps":ramps},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("Fuji real world driving / deck contacts / independent telemetry / pause / reverse / shoulders / traffic / recovery: ","PASS" if failures == 0 else "FAIL")
	return failures
