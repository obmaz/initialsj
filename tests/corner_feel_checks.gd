extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0


func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)


func make_race(tree: SceneTree) -> Node3D:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	return race


func fixture_curve(race: Node3D, curvature: float, bank: float = 0, origin: Vector3 = Vector3.ZERO) -> void:
	var road: Node3D = race.track.active
	road.closed_loop = false
	road.features.clear()
	road.bank_samples = PackedFloat32Array([bank, bank])
	var curve := Curve3D.new()
	curve.bake_interval = 1
	for i in range(2001):
		var d := i * 2.0
		var at := Vector3(0, 0, -d)
		if absf(curvature) > 0.000001:
			var angle := d * curvature
			at = Vector3((1 - cos(angle)) / curvature, 0, -sin(angle) / curvature)
		curve.add_point(origin + at)
	road.curve = curve
	road.length = curve.get_baked_length()
	if race.world_race != null:
		for tracker in race.world_race.trackers:
			tracker.configure(road)


func physical_floor(tree: SceneTree) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 4
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(500, 1, 500)
	collision.shape = shape
	body.add_child(collision)
	tree.root.add_child(body)
	body.position = Vector3(8000, 99.5, 8000)
	return body


func world_trial(
	tree: SceneTree,
	race: Node3D,
	axis: float,
	gas: bool = true,
	brake: bool = false,
	boost: bool = false,
	airborne: bool = false,
	initial: float = -1,
	duration: float = 0.55
) -> Dictionary:
	fixture_curve(race, 0, 0, Vector3(8000, 100, 8400))
	race.restart()
	race.state = "racing"
	for rival in race.rivals:
		rival.active = false
	var session: Node3D = race.world_race
	session.teleport(0, 400, 0)
	await tree.physics_frame
	await tree.physics_frame
	# Settle against the real floor, then seed an identical physical entry speed.
	race.step(1.0 / 60, 0, false, false, false)
	var body: CharacterBody3D = session.player_body
	if airborne:
		body.reset_pose(body.feet_position() + Vector3.UP * 30, Vector3.FORWARD)
	var before: float = race.vehicle.max_speed if initial < 0 else initial
	body.velocity = body.forward_direction() * before
	race.speed = before
	var peak_loss := 0.0
	var peak_load := 0.0
	for frame in range(roundi(duration * 60)):
		await tree.physics_frame
		race.step(1.0 / 60, axis, false, gas, brake, boost)
		if "last_corner_loss" in body:
			peak_loss = maxf(peak_loss, body.last_corner_loss)
		if "corner_demand" in body:
			peak_load = maxf(peak_load, body.corner_demand)
	return {
		"entry_mps": before,
		"exit_mps": race.speed,
		"lane": race.lane,
		"wall_hits": race.wall_hits,
		"offroad": race.offroad_amount,
		"airborne": not body.grounded,
		"axis": axis,
		"boost": boost,
		"peak_loss_mps2": peak_loss,
		"peak_lateral_mps2": peak_load,
		"seconds": duration
	}


func compare(rows: Dictionary, label: String) -> void:
	var straight: Dictionary = rows.straight
	var mild: Dictionary = rows.mild
	var tight: Dictionary = rows.tight
	check(
		absf(float(straight.exit_mps) - float(straight.entry_mps)) < 0.12,
		label + ": full-throttle straight speed must remain unchanged"
	)
	check(
		float(mild.exit_mps) < float(straight.exit_mps) - 0.02 and float(mild.exit_mps) > float(straight.exit_mps) - 2,
		label + ": a mild turn must have a small smooth scrub loss"
	)
	check(
		float(tight.exit_mps) < float(straight.exit_mps) - 3,
		label + ": a high-speed tight turn must shed at least 11 km/h in 0.55 seconds under throttle"
	)
	check(
		float(rows.boost.exit_mps) > float(tight.exit_mps) + 0.5,
		label + ": nitro must still provide more corner-exit force than normal throttle"
	)
	check(
		float(rows.boost.exit_mps) < float(rows.boost_straight.exit_mps) - 1,
		label + ": nitro must not erase actual corner resistance"
	)
	check(
		float(rows.brake.exit_mps) < float(tight.exit_mps) - 12,
		label + ": braking must override full throttle during a turn"
	)
	check(
		absf(float(rows.air.exit_mps) - float(straight.exit_mps)) < 0.12 and rows.air.airborne,
		label + ": steering while airborne must not apply grounded tyre scrub"
	)
	check(
		float(rows.launch.exit_mps) > float(rows.launch.entry_mps) + 4.2,
		label + ": 30% lower acceleration must still move the real car under low-speed throttle"
	)
	for key in rows:
		check(
			rows[key].wall_hits == 0 and float(rows[key].offroad) < 0.01,
			label + ": compare tyre resistance without impacts or dirt slowdown (" + key + ")"
		)


func run(tree: SceneTree) -> int:
	var scalar_rows := []
	var world := make_race(tree)
	world.choose_mode("track", 0)
	var floor := physical_floor(tree)
	await tree.physics_frame
	await tree.physics_frame
	var world_rows := []
	for choice in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		world.open_garage()
		world.select_vehicle(choice)
		var trials := {}
		trials.straight = await world_trial(tree, world, 0)
		trials.mild = await world_trial(tree, world, 0.025)
		trials.tight = await world_trial(tree, world, 0.35)
		trials.boost = await world_trial(tree, world, 0.35, true, false, true)
		trials.boost_straight = await world_trial(tree, world, 0, true, false, true)
		trials.brake = await world_trial(tree, world, 0.35, true, true)
		trials.air = await world_trial(tree, world, 0.35, true, false, false, true)
		trials.launch = await world_trial(tree, world, 0.35, true, false, false, false, 10)
		compare(trials, "Fuji world " + str(world.vehicle.id))
		world_rows.append({"vehicle": world.vehicle.id, "trials": trials})
	world.queue_free()
	floor.queue_free()
	await tree.process_frame
	FileAccess.open(Report.path("corner-feel-metrics.json"), FileAccess.WRITE).store_string(
		(
			JSON.stringify(
				{"assertions": assertions, "failures": failures, "scalar": scalar_rows, "world": world_rows}, "\t"
			)
			+ "\n"
		)
	)
	print(
		"Actual race corner resistance / straight / mild / tight / boost / braking / air / launch: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
