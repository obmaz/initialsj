extends RefCounted
const Surface = preload("res://scripts/track/road_surface_state.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 1)
	var section: Node3D = race.track.active
	var lanes: Array = section.features.filter(func(f): return f.kind == "boost_lane")
	var pads: Array = section.features.filter(func(f): return f.kind == "boost" and f.length <= 12)
	check(lanes.size() == 2 and pads.size() == 12, "Speedway needs two continuous lanes and two six-pad slaloms")
	var s = Surface.new()
	for lane in lanes:
		var p := Vector2(lane.lane, lane.distance)
		s.reset()
		s.contact(section, p, p, 80)
		check(
			s.lane_active and s.pad_time == 0 and s.boosts_hit == 0,
			"A lane must provide occupancy boost without timed credit or repeatable entry rewards"
		)
		s.contact(section, p, p + Vector2(lane.width, 0), 80)
		check(not s.lane_active and s.pad_time == 0, "Moving off the side must immediately remove lane boost")
		s.contact(section, p, p + Vector2(0, lane.length), 80)
		check(not s.lane_active, "Crossing the complete lane in a long frame must not grant lingering boost")
		s.update_lane(section, p, 80, true)
		check(not s.lane_active, "Braking must override the lane")
		s.update_lane(section, p, 80, false, 0, false)
		check(not s.lane_active, "Flying over a lane must not activate it")
		s.contact(section, p + Vector2(0, section.length), p + Vector2(0, section.length), 80)
		check(s.lane_active, "Occupancy must work on later laps")
	for pad in pads:
		s.reset()
		var p := Vector2(pad.lane, pad.distance)
		s.contact(section, p - Vector2(0, 20), p + Vector2(0, 20), 100)
		check(
			s.boosts_hit == 1 and s.pad_time <= 0.5,
			"Short slalom pads must activate on a fast sweep and give a brief burst"
		)
		s.reset()
		s.contact(section, Vector2(0, pad.distance - 20), Vector2(0, pad.distance + 20), 100)
		check(s.boosts_hit == 0, "The centre line must miss the alternating pads")
	for car in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(car)
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		var world: Node3D = race.world_race
		var lane: Dictionary = lanes[0]
		# The circuit is driven by real bodies: place the car on the lane and give it speed.
		world.teleport(0, lane.distance - 20, lane.lane, false)
		race.speed = race.vehicle.max_speed
		world.player_body.velocity = world.player_body.forward_direction() * race.vehicle.max_speed
		for frame in range(90):
			race.step(
				1.0 / 60,
				clampf((float(lane.lane) - race.lane) * 0.6 - race.lane_velocity * 0.12, -1, 1),
				false,
				true,
				false
			)
			if race.surface.lane_active:
				break
		check(race.pad_active and race.surface.lane_active, "Every vehicle must get lane acceleration on a boost lane")
		for frame in range(30):
			race.step(1.0 / 60, 0, false, true, false)
		check(race.speed > race.vehicle.max_speed - 1, "A vehicle on a lane must keep its full speed")
		world.teleport(0, lane.distance, 0.0, false)
		world.player_body.velocity = world.player_body.forward_direction() * race.vehicle.max_speed
		race.step(1.0 / 60, 0, false, true, false)
		check(
			not race.surface.lane_active and not race.pad_active,
			"Leaving the lane sideways must remove lane acceleration"
		)
		world.teleport(0, lane.distance, lane.lane, false)
		world.player_body.global_position += Vector3.UP * 4
		world.player_body.velocity = world.player_body.forward_direction() * 40
		race.step(1.0 / 60, 0, false, true, false)
		race.step(1.0 / 60, 0, false, true, false)
		check(not race.surface.lane_active, "Flying over a lane must clear its occupancy")
		race.restart()
		race.state = "racing"
		for rival in race.rivals:
			rival.active = false
		var chain: Array = pads.filter(func(f): return f.distance >= 2490)
		world.teleport(0, chain[0].distance - 35, chain[0].lane, false)
		# Real tyres limit how fast the slalom can be steered: take it at a moderate pace.
		race.speed = race.vehicle.max_speed * 0.55
		world.player_body.velocity = world.player_body.forward_direction() * race.speed
		for frame in range(900):
			var next := chain.size() - 1
			for index in range(chain.size()):
				if chain[index].distance > race.distance - 4:
					next = index
					break
			# Pure pursuit toward the next pad, like the long drive checks.
			var body: CharacterBody3D = world.player_body
			var forward: Vector3 = body.forward_direction()
			var right := Vector3(-forward.z, 0, forward.x).normalized()
			# Aim at the pad itself while it is close, so the car swings across in good time.
			var gap: float = maxf(18.0, float(chain[next].distance) - race.distance)
			var look := minf(gap, 55.0)
			var to: Vector3 = race.track.point(race.distance + look, float(chain[next].lane)) - body.feet_position()
			var angle := atan2(to.dot(right), to.dot(forward))
			var wheel: float = (
				(0.46 + race.vehicle.handling * 0.007)
				/ (1 + race.speed * 0.035)
				* world.WorldCar.steering_scale(race.speed)
			)
			var axis := clampf(atan(5.4 * sin(angle) / look) / wheel, -1, 1)
			race.step(1.0 / 60, axis, false, true, false)
			if race.distance > chain[-1].distance + 20:
				break
		check(
			race.surface.boosts_hit >= 3 and race.wall_hits == 0,
			(
				"%s: the alternating pads must remain steerable without wall hits (hits=%d, walls=%d)"
				% [race.vehicle.id, race.surface.boosts_hit, race.wall_hits]
			)
		)
	race.queue_free()
	await tree.process_frame
	print(
		"Short slalom pads / boost-lane occupancy / brakes / airborne / all vehicles: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
