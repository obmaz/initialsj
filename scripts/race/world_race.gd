extends Node3D
# 트랙과 투어의 공통 실제 3D 차체·접지·충돌·카메라. 도로 좌표는 계측에만 사용한다.
const RoadRecovery = preload("res://scripts/race/road_recovery.gd")
const RaceState = preload("res://scripts/race/race_state.gd")
const WorldCar = preload("res://scripts/physics/world_car.gd")
const Progress = preload("res://scripts/race/circuit_progress.gd")
const TourProgress = preload("res://scripts/race/tour_progress.gd")
const RivalState = preload("res://scripts/race/rival_state.gd")
const RivalDriving = preload("res://scripts/race/rival_driving.gd")
const Nitro = preload("res://scripts/race/nitro_system.gd")
const Power = preload("res://scripts/physics/drive_power.gd")
const Corner = preload("res://scripts/physics/corner_resistance.gd")
const Tuning = preload("res://scripts/physics/drive_tuning.gd")
var race: Node3D
var player_body: CharacterBody3D
var bodies: Array[CharacterBody3D] = []
var trackers: Array[RefCounted] = []
var reverse_wait := 0.0
var reversing := false
var recovery_clock := 0.0
var safe_distance := 80.0
var safe_lane := -3.2
var airborne_time := 0.0
var landing_velocity := 0.0
var wrong_way_time := 0.0
var crash_flight := false
var outside_time := 0.0
var contact_flow := preload("res://scripts/race/contact_flow.gd").new()
var camera_state := preload("res://scripts/effects/chase_camera_state.gd").new()


func setup() -> void:
	for i in range(race.competitor_count()):
		var body: CharacterBody3D = WorldCar.new()
		body.name = "PlayerWorldBody" if i == 0 else "RivalWorldBody" + str(i)
		body.cheap_adhesion = i > 0
		body.coast_profile = i == 0
		add_child(body)
		bodies.append(body)
		var tracker: RefCounted = Progress.new() if race.mode == "track" else TourProgress.new()
		tracker.configure(race.track.active if race.mode == "track" else race.track)
		trackers.append(tracker)
	player_body = bodies[0]


func shutdown() -> void:
	# A queued old scene must not leave colliders in the next mode's first frame.
	for body in bodies:
		body.collision_layer = 0
		body.collision_mask = 0


func road_up(d: float) -> Vector3:
	var forward: Vector3 = (race.track.point(d + 1) - race.track.point(d - 1)).normalized()
	var right: Vector3 = (race.track.point(d, 1) - race.track.point(d, -1)).normalized()
	return right.cross(forward).normalized()


func reset() -> void:
	camera_state.reset()
	contact_flow.reset()
	reverse_wait = 0
	reversing = false
	recovery_clock = 0
	airborne_time = 0
	landing_velocity = 0
	wrong_way_time = 0
	crash_flight = false
	safe_distance = 80
	safe_lane = -3.2
	outside_time = 0
	race.protection_left = 0
	race.player.set_protection(false)
	player_body.collision_layer = 4
	player_body.collision_mask = 15
	player_body.rescue_floor.clear()
	for i in range(bodies.size()):
		var d: float = 80 if i == 0 else race.rivals[i - 1].distance
		var lane: float = -3.2 if i == 0 else race.rivals[i - 1].lane
		bodies[i].configure(race.vehicle if i == 0 else race.rivals[i - 1].specification)
		teleport(i, d, lane)


func teleport(index: int, d: float, lane: float = 0.0, reset_progress: bool = true) -> void:
	var feet: Vector3 = race.track.point(d, lane) + road_up(d) * 0.04
	var forward: Vector3 = race.track.point(d + 2, lane) - race.track.point(d - 2, lane)
	bodies[index].reset_pose(feet, forward, road_up(d))
	if reset_progress:
		trackers[index].reset(d)
	else:
		trackers[index].reposition(d)
	trackers[index].lane = lane
	if index == 0:
		contact_flow.reset()
		race.distance = d
		race.lane = lane
		race.speed = 0
		race.air.reset()
		airborne_time = 0
		landing_velocity = 0
		wrong_way_time = 0
		crash_flight = false
		race.player.reset_physics_interpolation()
		race.player.body_motion.reset()
		race.sound_state.reset()
		race.proximity_audio.reset()
		race.slipstream.cancel()
		race.acoustics.reset()
		race.sound_state.last_reward = race.rewards.event_id
		race.camera.reset_physics_interpolation()
		camera_state.reset()
	else:
		var rival: RivalState = race.rivals[index - 1]
		rival.distance = d
		rival.lane = lane
		rival.target_lane = lane
		rival.decision = RivalState.decision_phase(rival.id)
		rival.speed_plan_time_left = 0
		rival.planned_curve_speed_limit = INF
		rival.planned_traffic_speed_limit = INF
		rival.planned_boost_curvature = 0
		rival.lod_time = 0
		rival.world_stuck = 0.0
		rival.world_reverse = 0.0
		rival.world_reverse_cooldown = 0.0
		rival.world_reverse_axis = 0.0


func speed_of(body: CharacterBody3D) -> float:
	return (
		body.velocity.slide(body.surface_normal).length()
		if body.grounded
		else Vector2(body.velocity.x, body.velocity.z).length()
	)


func frame(body: CharacterBody3D, visual: Node3D) -> Transform3D:
	# Authored body offsets differ between selected cars and traffic models.
	return body.visual_frame(visual.ride_offset)


func place_cars() -> void:
	race.player.global_transform = frame(player_body, race.player)
	race.player.body.rotation.y = 0
	for i in range(1, bodies.size()):
		var rival: RivalState = race.rivals[i - 1]
		rival.car.global_transform = frame(bodies[i], rival.car)
		rival.car.body.rotation.y = 0
		rival.car.visible = rival.active and bodies[i].position.distance_to(player_body.position) < 460
		rival.car.set_detail(bodies[i].position.distance_to(player_body.position))
	for i in range(bodies.size() - 1, race.rivals.size()):
		race.rivals[i].car.visible = false


func step(
	delta: float, axis: float, drift_input: bool, gas: bool, brake: bool, nitro_input: bool, cell_input: bool
) -> void:
	for i in range(1, bodies.size()):
		var layer := 4 if race.rivals[i - 1].active else 0
		if bodies[i].collision_layer != layer:
			bodies[i].collision_layer = layer
			bodies[i].collision_mask = 15 if layer else 0
	update_protection(delta)
	race.rewards.tick(delta)
	var old_position := Vector2(race.lane, race.distance)
	var old_gaps: Array[float] = []
	for i in range(bodies.size() - 1):
		old_gaps.append(race.relative_gap(race.rivals[i].distance, race.distance))
	var was_airborne: bool = race.air.active
	race.elapsed += delta
	for field in ["near_miss_flash", "overtake_flash", "checkpoint_flash", "launch_flash"]:
		race.set(field, maxf(0, float(race.get(field)) - delta))
	race.impact = maxf(0, race.impact - delta * 3.5)
	race.impact_age += delta
	race.bump_cooldown = maxf(0, race.bump_cooldown - delta)
	race.boost_kick = maxf(0, race.boost_kick - delta * 2)
	race.surface.tick(delta, brake, race.impact)
	gas = (
		gas
		or nitro_input
		or (cell_input and race.vehicle.mode == "hybrid")
		or race.nitro_burst_left > 0
		or race.surface.pad_time > 0
	)
	race.throttling = gas and not brake
	race.braking = brake
	race.steer = move_toward(race.steer, axis, delta * race.vehicle.steer_rate)
	update_drift(delta, drift_input, brake, gas)
	race.drafting = race.slipstream.prepare(race, delta)
	race.draft_charge = move_toward(race.draft_charge, 1 if race.drafting else 0, delta)
	Nitro.update(race, delta, nitro_input, cell_input)
	var cap: float = race.vehicle.max_speed + race.draft_charge * 8
	var accel: float = race.vehicle.accel
	if race.nitro_active:
		cap = race.vehicle.overdrive_speed if race.nitro_burst_left > 0 else race.vehicle.boost_speed
		accel = race.vehicle.boost_accel
	if race.reward_boost_active():
		cap = maxf(cap, race.vehicle.max_speed + race.rewards.boost_gain)
		accel = maxf(accel, race.vehicle.accel * 1.25)
	if race.pad_active:
		cap = maxf(cap, race.pad_speed_cap())
		accel = maxf(accel, race.vehicle.boost_accel + 8.4)
	cap *= lerpf(1, 0.58, race.offroad_amount)
	if player_body.grounded:
		accel *= Corner.engine_factor(race.speed, cap, player_body.corner_demand, player_body.corner_grip)
	var target: float = Power.target(race.speed, cap, accel, delta, gas, race.offroad_amount)
	if race.drifting:
		target = Power.target(race.speed, cap * .98, accel * .45, delta, gas, race.offroad_amount)
	if brake:
		target = maxf(0, race.speed - race.vehicle.brake * delta)
	reverse_wait = reverse_wait + delta if brake and race.speed < 1.5 else 0.0
	if not brake:
		reversing = false
	if reverse_wait > 0.45:
		reversing = true
	if reversing:
		target = -10
	var signed_speed: float = player_body.velocity.dot(player_body.forward_direction())
	if not reversing and signed_speed < -0.5:
		target = move_toward(signed_speed, 0, (race.vehicle.brake if gas else 5) * delta)
	if race.crash.active:
		# Air motion remains ballistic. Once grounded, settle the signed rebound
		# instead of accelerating the chassis head-first into the same barrier.
		target = move_toward(signed_speed, 0, race.vehicle.brake * 0.8 * delta)
	var grip: float = race.surface.grip_factor * lerpf(1, 0.72, race.offroad_amount)
	grip *= preload("res://scripts/track/harbor_corridor.gd").grip(race.track.active, race.distance)
	var ahead: float = race.distance + 6.0
	player_body.road_heading = (
		(race.track.point(ahead, race.lane) - race.track.point(race.distance, race.lane)).normalized()
	)
	var contacts: Array = player_body.advance(delta, race.steer, target, race.drifting, grip)
	var data: Dictionary = trackers[0].update(player_body.feet_position(), delta)
	race.distance = float(data.distance)
	race.lane = float(data.lane)
	race.speed = speed_of(player_body)
	race.lane_velocity = player_body.velocity.dot(player_body.global_basis.x)
	race.slip_angle = player_body.slip_angle
	var outside := (
		clampf((absf(race.lane) + 0.8 - race.track.half_width(race.distance)) / 1.6, 0, 1)
		if player_body.grounded
		else 0.0
	)
	race.offroad_amount = move_toward(race.offroad_amount, outside, delta * 6)
	update_air(delta, was_airborne)
	# Boost lanes only count while the wheels are on the road.
	race.surface.update_lane(
		race.track.active,
		Vector2(race.lane, race.distance),
		race.speed,
		brake,
		race.impact,
		player_body.grounded and not race.crash.active
	)
	if player_body.grounded and not was_airborne and data.valid:
		for event in race.surface.contact(
			race.track.active, old_position, Vector2(race.lane, race.distance), race.speed, brake, race.impact
		):
			if event == "boost":
				player_body.velocity += player_body.forward_direction() * 8
				race.score += 50
				race.boost_kick = 0.55
				race.haptics.pulse(0.25, 0.8, 0.18, 2)
			elif event == "mud":
				player_body.velocity *= 0.88
			elif event == "water":
				player_body.velocity *= 0.96
				if DisplayServer.get_name() != "headless":
					race.water_effect.burst(
						player_body.feet_position(), player_body.forward_direction(), race.motion_reduced
					)
	if race.surface.mud_time > 0 and player_body.grounded:
		player_body.velocity = player_body.velocity.move_toward(Vector3(0, player_body.velocity.y, 0), 24 * delta)
	for hit in contacts:
		contact_flow.contact(bool(hit.get("barrier", false)))
		impact(hit)
		# Gliding along a rail throws sparks and rumbles until the car leaves it.
		if hit.get("barrier", false) and not hit.get("severe", false) and race.speed > Tuning.SCRAPE_SPEED:
			race.scrape(delta, -hit.normal, hit.point)
	# A sliding car touches the rail only on the first frame, so keep the scrape going from its
	# distance to the rail line while it stays pressed against it.
	if player_body.grounded and race.speed > Tuning.SCRAPE_SPEED and not race.crash.active and not fork_area():
		var rail_side := signf(race.lane)
		var rail_gap: float = (
			race.track.half_width(race.distance)
			+ race.track.active.rail_setback(race.distance, rail_side)
			- absf(race.lane)
			- 1.1
		)
		if rail_gap < 0.45:
			race.scrape(
				delta,
				player_body.global_basis.x * rail_side,
				player_body.feet_position() + player_body.global_basis.x * rail_side * 1.1 + Vector3.UP * 0.4
			)
		elif rail_gap < 1.25:
			race.edge_rumble = maxf(race.edge_rumble, 0.5)
			race.haptics.pulse(0.08, 0.12, 0.05, 1)
	advance_contact(delta)
	if race.mode == "tour":
		race.speed = speed_of(player_body)
	update_rivals(delta)
	update_passes(old_gaps, old_position.y)
	update_tour_passes(old_position.y)
	race.slipstream.finish(race, delta)
	var road_forward: Vector3 = (race.track.point(race.distance + 2) - race.track.point(race.distance - 2)).normalized()
	wrong_way_time = (
		wrong_way_time + delta if player_body.velocity.dot(road_forward) < -5 and player_body.grounded else 0.0
	)
	if race.coast_handling:
		race.score += race.coast_drift.step(
			delta,
			race.speed,
			race.slip_angle,
			race.drifting,
			player_body.grounded,
			(
				race.offroad_amount < 0.15
				and race.impact < 0.15
				and not race.crash.active
				and not contact_flow.sustained()
			),
			contact_flow.reward_hold > 0
		)
	elif race.drifting and player_body.grounded and race.offroad_amount < 0.15 and contact_flow.reward_hold <= 0:
		race.score += delta * race.speed * (2 + race.drift_charge)
	var clean_exit: bool = (
		player_body.grounded
		and not race.crash.active
		and race.protection_left <= 0
		and race.offroad_amount < 0.15
		and race.impact < 0.15
		and race.throttling
		and not contact_flow.sustained()
	)
	var corner_key: String = (
		"%s:%s:%d:%d:%d"
		% [race.mode, race.selected_course, race.stage_index, race.laps_completed, int(old_position.y / 100)]
	)
	race.score += race.rewards.drift_step(
		delta,
		race.drifting,
		race.slip_angle,
		race.speed,
		race.distance - old_position.y,
		race.track.curvature(race.distance),
		clean_exit,
		corner_key,
		contact_flow.reward_hold > 0
	)
	if was_airborne and player_body.grounded:
		race.route_challenges.land(race, clean_exit and not crash_flight)
	race.route_challenges.observe(race)
	race.boosting = (
		race.nitro_active
		or race.pad_active
		or race.reward_boost_active()
		or (race.draft_charge > 0.65 and race.throttling)
	)
	race.max_drift_multiplier = maxi(race.max_drift_multiplier, race.coast_drift.multiplier)
	race.personal_run.observe(
		race, bool(data.valid) and race.protection_left <= 0 and player_body.velocity.dot(road_forward) >= -1, delta
	)
	if race.mode == "track":
		race.time_left = maxf(0, race.time_left - delta)
		while race.distance >= race.circuit_checkpoint * race.track.length * .5:
			var gate_distance: float = race.circuit_checkpoint * race.track.length * .5
			# 검증 게이트는 그리드 위치에서 시작하므로 코스 원점과의 차이를 반영한다.
			var required := maxi(
				0,
				floori((gate_distance - trackers[0].start_distance) / (race.track.length / Progress.GATE_COUNT) + .0001)
			)
			if bool(data.valid) and race.protection_left <= 0 and trackers[0].gates_passed >= required:
				race.checkpoint_award = race.circuit_time_bonus()
				race.time_left += race.checkpoint_award
				race.checkpoint_flash = 2
			race.circuit_checkpoint += 1
		if race.time_left <= 0:
			race.state = RaceState.FAILED
			race.result_age = 0
			race.cancel_nitro()
			race.personal_run.finish(race, false)
	var laps: int = int(data.finished_laps)
	if laps > race.laps_completed:
		race.laps_completed = laps
		race.last_lap = race.elapsed - race.lap_started
		if race.selected_course == 1 and race.mode == "track":
			race.track.active.speedway_board.add_result(race.last_lap, str(race.vehicle.name), race.save_records)
		race.lap_started = race.elapsed
		race.checkpoint_flash = 2
		race.nitro = minf(100, race.nitro + 15)
		race.nitro_charges = mini(race.vehicle.charges, race.nitro_charges + 1)
		if laps >= 3:
			race.finish()
	update_recovery(delta, data)
	var curve: float = absf(race.track.curvature(race.distance + 35))
	race.recommended_speed = minf(race.vehicle.max_speed, sqrt(race.vehicle.grip * 1.4 / maxf(curve, 0.0001)))
	race.corner_warning = move_toward(
		race.corner_warning, clampf((race.speed - race.recommended_speed - 4) / 15, 0, 1), delta * 3
	)


func advance_contact(delta: float) -> void:
	if not contact_flow.wall_latched:
		contact_flow.advance(delta, false)
		return
	var side := signf(race.lane)
	var edge: float = race.track.half_width(race.distance) + race.track.active.rail_setback(race.distance, side)
	# 실제 접촉 뒤의 짧은 안쪽 반동은 허용하되 벽 쪽 조향이 계속될 때만 누적한다.
	var pressed: bool = (
		player_body.grounded
		and not fork_area()
		and not race.crash.active
		and edge - absf(race.lane) - 1.1 < .75
		and race.steer * side > .15
	)
	contact_flow.advance(delta, pressed)
	if contact_flow.sustained():
		race.interrupt_drive()
		var vertical: Vector3 = player_body.surface_normal * player_body.velocity.dot(player_body.surface_normal)
		player_body.velocity = vertical + (player_body.velocity - vertical).move_toward(Vector3.ZERO, 12 * delta)
		race.speed = speed_of(player_body)


func update_drift(delta: float, pressed: bool, brake: bool, gas: bool) -> void:
	var tap: bool = pressed and not race.drift_previous_input
	race.drift_previous_input = pressed
	race.drift_pending = maxf(0, race.drift_pending - delta)
	var ended: bool = tap and race.drift_latched
	if ended:
		race.drift_latched = false
		race.drift_pending = 0
	elif tap:
		race.drift_pending = 0.55
	if brake and not race.previous_brake:
		race.brake_armed = 0.45
	race.brake_armed = maxf(0, race.brake_armed - delta)
	if (
		not ended
		and player_body.grounded
		and race.speed > 25
		and absf(race.steer) > 0.08
		and (
			race.drift_pending > 0
			or (race.previous_brake and not brake and race.brake_armed > 0.25 and gas and absf(race.steer) > 0.35)
		)
	):
		race.drift_latched = true
		race.drift_sign = signf(race.steer)
		race.drift_pending = 0
	if not player_body.grounded or race.speed < 22 or brake and absf(race.steer) < 0.04:
		race.drift_latched = false
	if absf(race.steer) < 0.04 and absf(player_body.slip_angle) < 0.12:
		race.drift_straight += delta
		if race.drift_straight > 0.4:
			race.drift_latched = false
	else:
		race.drift_straight = 0
	var was: bool = race.drifting
	race.drifting = race.drift_latched
	if race.drifting:
		race.drift_charge += delta
	elif was:
		if race.drift_charge > 0.55:
			race.drifts_completed += 1
		race.drift_charge = 0
	race.previous_brake = brake


func update_air(delta: float, was_airborne: bool) -> void:
	# A thrown car turns its nose back to where it is travelling, so it lands driving forward.
	if not player_body.grounded:
		player_body.turn_toward(player_body.velocity, Tuning.FLIGHT_TURN_RATE, delta)
	race.air.landing_flash = maxf(0, race.air.landing_flash - delta)
	race.air.active = not player_body.grounded
	race.air.world_y = player_body.feet_position().y
	race.air.height = maxf(0, race.air.world_y - race.track.point(race.distance, race.lane).y)
	race.air.velocity = player_body.velocity.y
	if race.air.active:
		airborne_time += delta
		landing_velocity = minf(landing_velocity, player_body.velocity.y)
	if not was_airborne and race.air.active:
		race.air.trick = player_body.velocity.y > 1.5 and race.speed > 20
		if race.air.trick:
			race.air.launches += 1
			race.route_challenges.launch(race)
	if was_airborne and not race.air.active:
		player_body.turn_toward(player_body.velocity, 1.0 / delta, delta)
		race.crash.reset()
		race.player.body.rotation = Vector3.ZERO
		race.player.body.position = Vector3(0, race.player.ride_offset, 0)
		race.air.landings += 1
		if airborne_time > 0.12 and landing_velocity < -1.5:
			race.air.landing_flash = 0.65
			race.air.landing_strength = clampf(-landing_velocity / 14, 0.25, 1)
			race.player.body_motion.land(race.air.landing_strength * (.3 if race.motion_reduced else 1.0))
			race.haptics.pulse(0.4 + 0.5 * race.air.landing_strength, 0.6, 0.12 + 0.2 * race.air.landing_strength, 3)
			if not crash_flight:
				race.score += 100
			if DisplayServer.get_name() != "headless":
				race.landing_dust.burst(player_body.feet_position(), race.motion_reduced)
		airborne_time = 0
		landing_velocity = 0
		crash_flight = false


func update_passes(old_gaps: Array[float], previous_distance: float) -> void:
	if race.distance <= previous_distance or player_body.velocity.dot(player_body.forward_direction()) < 10:
		return
	for i in range(bodies.size() - 1):
		var rival: RivalState = race.rivals[i]
		if not rival.active:
			continue
		var gap: float = race.relative_gap(rival.distance, race.distance)
		var relative := bodies[i + 1].position - player_body.position
		if old_gaps[i] <= 0 or gap > 0 or relative.length() > 9 or absf(relative.y) > 1.5:
			continue
		race.overtakes += 1
		race.overtake_flash = 1
		race.score += 100
		var lateral := absf(relative.dot(player_body.global_basis.x))
		if lateral > 2.15 and lateral < 3.8 and race.bump_cooldown <= 0:
			race.near_misses += 1
			race.near_miss_flash = 1.1
			race.nitro = minf(100, race.nitro + 6)
			race.score += 150


func update_tour_passes(previous_distance: float) -> void:
	if race.mode != "tour":
		return
	var clean: bool = (
		player_body.grounded
		and race.protection_left <= 0
		and race.impact_age > 1
		and race.offroad_amount < 0.15
		and race.speed > 25
		and race.distance > previous_distance
		and player_body.velocity.dot(player_body.road_heading) > 20
	)
	if not clean:
		race.rewards.break_pass_chain()
	var forward: Vector3 = player_body.road_heading.slide(Vector3.UP).normalized()
	var right := Vector3(-forward.z, 0, forward.x)
	for other in get_tree().get_nodes_in_group("tour_road_traffic"):
		if other.clock != race:
			continue
		var relative: Vector3 = other.feet_position() - player_body.feet_position()
		if relative.length_squared() > 45 * 45:
			continue
		if race.rewards.observe_traffic(
			other.get_instance_id(), relative.dot(forward), absf(relative.dot(right)), absf(relative.y), clean
		):
			race.overtakes += 1
			race.near_misses += 1
			race.near_miss_flash = 1.1
			race.score += 150 * race.rewards.pass_chain
			if race.vehicle.mode != "charges":
				race.nitro = minf(100, race.nitro + 6 + race.rewards.pass_chain * 2)
			if race.vehicle.mode != "gauge" and race.rewards.close_passes % 4 == 0:
				race.nitro_charges = mini(race.vehicle.charges, race.nitro_charges + 1)


func impact(hit: Dictionary) -> void:
	var normal: Vector3 = hit.normal
	var forward: Vector3 = player_body.forward_direction()
	var local := Vector2(normal.dot(player_body.global_basis.x), -normal.dot(forward))
	var barrier: bool = hit.collider is StaticBody3D and hit.collider.get_collision_layer_value(2)
	var incoming: float = hit.get("incoming_speed", race.speed)
	var closing: float = hit.get("closing_speed", hit.speed)
	if barrier and hit.get("severe", false) and not race.crash.active:
		var severity: float = race.crash.severity(incoming)
		var up: float = Tuning.world_launch_up(race.crash.launch_up(incoming))
		race.crash.start(incoming, local, player_body.feet_position().y, 2.0 * up / player_body.GRAVITY)
		player_body.realign_time = 0.0
		race.haptics.pulse(1.0, 1.0, 0.5, 4)
		crash_flight = true
		var outward := normal.slide(Vector3.UP).normalized()
		var tangent := player_body.velocity.slide(normal)
		tangent.y = 0
		# 큰 진입각의 고속 충돌에만 제한된 높이의 비행을 적용한다.
		var away := (lerpf(3.5, 12.0, severity) + clampf(closing * 0.12, 0, 4)) * Tuning.LAUNCH_AWAY_SCALE
		player_body.velocity = tangent * lerpf(0.82, 0.66, severity) + outward * away + Vector3.UP * up
		player_body.grounded = false
		race.air.active = true
		race.air.trick = false
		race.air.world_y = player_body.feet_position().y
		race.air.velocity = player_body.velocity.y
		airborne_time = 0
		landing_velocity = 0
		reverse_wait = 0
		reversing = false
		# A recent gentle scrape must not suppress a genuine severe impact.
		race.bump_cooldown = 0
	var strength := smoothstep(2.5, 65, float(hit.speed))
	if race.bump_cooldown > 0 and (strength < .15 or race.impact_recoil >= .15):
		return
	if (
		hit.collider is CharacterBody3D
		or hit.collider.get_meta("parked_truck", false)
		or hit.collider.get_meta("parked_car", false)
	):
		race.traffic_hits += 1
	else:
		race.wall_hits += 1
	race.register_impact(strength, local, hit.point)
	# 일반 접촉은 멈춤 연출 없이 반동이 바로 보이도록 한다.
	if not hit.get("severe", false):
		race.hitstop_until = 0


func rival_lane(index: int, d: float, look: float, delta: float) -> float:
	var rival: RivalState = race.rivals[index - 1]
	var edge: float = minf(race.track.half_width(d), race.track.half_width(d + look)) - 1.5
	rival.target_lane = clampf(float(rival.target_lane), -edge, edge)
	rival.decision -= delta
	if rival.decision > 0:
		return rival.target_lane
	rival.decision = RivalState.DECISION_INTERVAL
	var body := bodies[index]
	var current: float = trackers[index].lane
	var chosen: float = rival.target_lane
	var best := INF
	# Keep the chosen line between decisions instead of crossing both grid
	# columns towards two hard-coded lanes. Outer lanes leave a full car margin.
	for candidate in [chosen, clampf(current, -edge, edge), -edge * 0.75, -edge * 0.25, edge * 0.25, edge * 0.75]:
		var cost: float = (
			(absf(candidate - current) * 0.65 + absf(candidate - float(rival.target_lane)) * 0.5)
			* float(rival.style.lane_cost)
		)
		for j in range(bodies.size()):
			if j == index or (j > 0 and not race.rivals[j - 1].active):
				continue
			var other := bodies[j]
			var relative := other.position - body.position
			if absf(relative.y) > 3 or relative.length_squared() > 110 * 110:
				continue
			var gap: float = race.relative_gap(trackers[j].distance, d)
			if gap < -20 or gap > 80:
				continue
			var other_lane: float = trackers[j].lane
			var clearance := absf(candidate - other_lane)
			# Reject a lane change through a car alongside, including a fast car
			# arriving from behind. A nearby leader can still be passed by first
			# reversing into free physical space when there is no turning room.
			var rear_reach := 6 + maxf(0, speed_of(other) - speed_of(body)) * 0.6
			if (
				gap > -rear_reach
				and gap < 5.2
				and other_lane > minf(current, candidate) - 2.5
				and other_lane < maxf(current, candidate) + 2.5
			):
				if absf(candidate - current) > 0.6:
					cost += 10000
			if gap >= 0 and clearance < 3.6:
				cost += (80 - gap) * (3.6 - clearance) * (1 + clampf((speed_of(body) - speed_of(other)) / 15, 0, 2))
			elif gap < 0 and clearance < 3.2:
				cost += maxf(0, 20 + gap) * (3.2 - clearance) * 4
		if cost < best:
			best = cost
			chosen = candidate
	rival.target_lane = chosen
	return chosen


func rival_rear_clear(index: int) -> bool:
	var body := bodies[index]
	var forward: Vector3 = body.forward_direction()
	var right: Vector3 = body.global_basis.x
	for j in range(bodies.size()):
		if j == index or (j > 0 and not race.rivals[j - 1].active):
			continue
		var relative := bodies[j].position - body.position
		if absf(relative.y) > 3:
			continue
		var behind := relative.dot(forward)
		if behind < 1 and behind > -12 and absf(relative.dot(right)) < 3.2:
			return false
	return true


# Rival bodies are the most expensive thing in a frame (each one ray-casts its tyres and sweeps
# against the track mesh). Cars near the player are simulated every frame; farther ones every 2nd
# or 3rd frame with the accumulated time, and glide on their last velocity in between so they
# never visibly step. They are also invisible beyond about 460 m.
const LOD_NEAR_SQ := 45.0 * 45.0
const LOD_MID_SQ := 150.0 * 150.0


# 1: every frame, 2: every other frame, 0: not simulated at all, just carried along the road.
func rival_stride(body: CharacterBody3D) -> int:
	var d2: float = body.position.distance_squared_to(player_body.position)
	if d2 < LOD_NEAR_SQ:
		return 1
	return 2 if d2 < LOD_MID_SQ else 0


# A rival far from the player can touch nothing the player sees: skip its body physics and move
# it along its lane, at the speed the AI would have chosen. It becomes a real body again, with the
# same pose and speed, when it comes within range.
func carry_rival(index: int, rival: RivalState, target_lane: float, target_speed: float, dt: float) -> void:
	var body := bodies[index]
	var tracker: RefCounted = trackers[index]
	var now := speed_of(body)
	var must_brake: bool = rival.planned_curve_speed_limit < now or rival.planned_traffic_speed_limit < now
	var acceleration: float = rival.specification.boost_accel if rival.nitro_active else rival.specification.accel
	var next_speed: float = (
		move_toward(now, target_speed, dt * rival.specification.brake)
		if target_speed < now and must_brake
		else Power.target(now, target_speed, acceleration, dt, true)
	)
	var old := Vector2(rival.lane, rival.distance)
	var next_distance: float = tracker.distance + next_speed * dt
	var edge: float = race.track.half_width(next_distance) - 2.0
	var next_lane := move_toward(tracker.lane, clampf(target_lane, -edge, edge), dt * 2.5)
	var up := road_up(next_distance)
	var forward: Vector3 = (
		race.track.point(next_distance + 2, next_lane) - race.track.point(next_distance - 2, next_lane)
	)
	body.reset_pose(race.track.point(next_distance, next_lane) + up * 0.04, forward, up)
	body.velocity = body.forward_direction() * next_speed
	body.grounded = true
	tracker.reposition(next_distance)
	tracker.lane = next_lane
	if tracker.has_method("seed_carried_pose"):
		tracker.seed_carried_pose(body.feet_position())
	rival.distance = next_distance
	rival.lane = next_lane
	rival.speed = next_speed
	rival.air.active = false
	rival.air.height = 0.0
	rival.drifting = false
	rival.surface.contact(race.track.active, old, Vector2(next_lane, next_distance), next_speed)
	rival.boosting = rival.surface.pad_time > 0 or rival.nitro_active


func plan_rival_speed(index: int, d: float, look: float, forward: Vector3) -> void:
	var rival: RivalState = race.rivals[index - 1]
	rival.planned_curve_speed_limit = INF
	for ahead in [0.0, 25.0, 55.0, 95.0, 145.0]:
		var curve: float = absf(race.track.curvature(d + ahead))
		var safe: float = sqrt(rival.specification.grip * float(rival.style.corner) / maxf(curve, 0.0001))
		rival.planned_curve_speed_limit = minf(
			rival.planned_curve_speed_limit, sqrt(safe * safe + 2 * minf(28, float(rival.specification.brake)) * ahead)
		)
	rival.planned_boost_curvature = absf(race.track.curvature(d + look))
	rival.planned_traffic_speed_limit = INF
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	for j in range(bodies.size()):
		if j == index or (j > 0 and not race.rivals[j - 1].active):
			continue
		var relative := bodies[j].position - bodies[index].position
		var gap := relative.dot(forward)
		if gap > 0 and gap < 40 and absf(relative.dot(right)) < 2.4 and absf(relative.y) < 3:
			var other_speed := speed_of(bodies[j])
			rival.planned_traffic_speed_limit = minf(
				rival.planned_traffic_speed_limit,
				sqrt(other_speed * other_speed + 2 * minf(30, float(rival.specification.brake)) * maxf(0, gap - 7))
			)


func update_rivals(delta: float) -> void:
	for i in range(1, bodies.size()):
		var rival: RivalState = race.rivals[i - 1]
		if not rival.active:
			continue
		var body := bodies[i]
		var stride := rival_stride(body)
		var carried := stride == 0
		# A car in the air or recovering from a hit always gets the full simulation.
		if carried or not body.grounded or rival.air.active or not body.last_contacts.is_empty():
			stride = 1
		var owed: float = rival.lod_time + delta
		# Stride-2 cars take turns: odd cars on odd ticks, even cars on even ticks.
		if stride > 1 and (Engine.get_physics_frames() + i) % stride != 0:
			rival.lod_time = owed
			var glide := body.velocity * delta
			glide.y = 0
			body.global_position += glide
			rival.distance += float(rival.speed) * delta
			continue
		rival.lod_time = 0.0
		var dt := owed
		var was_airborne: bool = rival.air.active
		var d: float = trackers[i].distance
		var now := speed_of(body)
		var look := clampf(now * 0.65, 15, 48)
		var target_lane := rival_lane(i, d, look, dt)
		if race.track.active.collapse != null:
			var collapse: Node3D = race.track.active.collapse
			var section_d: float = fposmod(d, race.track.length)
			if section_d > collapse.span.x - 300 and section_d < collapse.span.y + 30:
				target_lane = minf(target_lane, 1.0)
		if race.track.active.rockfall != null:
			target_lane = race.track.active.rockfall.safe_lane(d, target_lane)
		if race.track.active.closed_loop and race.track.active.course_id == 3:
			target_lane = race.track.scenery.rock_arches.safe_lane(d, target_lane)
		var target: Vector3 = race.track.point(d + look, target_lane)
		var direction: Vector3 = target - body.feet_position()
		var forward: Vector3 = body.forward_direction()
		var right := Vector3(-forward.z, 0, forward.x).normalized()
		var angle := atan2(direction.dot(right), direction.dot(forward))
		var wheel: float = (
			(0.46 + rival.specification.handling * 0.007) / (1 + now * 0.035) * WorldCar.steering_scale(now)
		)
		var axis := clampf(atan(5.4 * sin(angle) / look) / wheel, -1, 1)
		if absf(angle) > 1.1:
			axis = signf(angle)
		rival.surface.tick(dt)
		var target_speed: float = rival.pace + (18 if rival.surface.pad_time > 0 else 0)
		if absf(angle) > 1.1:
			target_speed = minf(target_speed, 10)
		var dirt := clampf((absf(rival.lane) + 0.8 - race.track.half_width(d)) / 1.6, 0, 1)
		target_speed *= lerpf(1, 0.58, dirt)
		rival.speed_plan_time_left -= dt
		# 150m 밖의 운반 차량만 계획을 재사용한다. 근접 복귀·접촉·공중 상태는 즉시 갱신한다.
		if (
			not carried
			or not body.grounded
			or rival.air.active
			or not body.last_contacts.is_empty()
			or rival.speed_plan_time_left <= 0
		):
			plan_rival_speed(i, d, look, forward)
			rival.speed_plan_time_left = RivalState.FAR_SPEED_PLAN_INTERVAL
		var curve_cap: float = rival.planned_curve_speed_limit
		target_speed = minf(target_speed, minf(curve_cap, rival.planned_traffic_speed_limit))
		var blocked: bool = rival.planned_traffic_speed_limit < INF
		var lap: int = maxi(0, floori((d - 80) / race.track.length))
		if lap > rival.boost_lap:
			rival.boost_lap = lap
			rival.boost_charges = mini(int(rival.specification.charges), rival.boost_charges + 1)
		var used_nitro := RivalDriving.nitro(
			rival,
			dt,
			rival.planned_boost_curvature,
			now,
			not blocked and body.grounded and rival.world_reverse <= 0 and absf(angle) < 0.35
		)
		if used_nitro:
			target_speed = minf(
				float(rival.specification.overdrive_speed if rival.boost_cell else rival.specification.boost_speed),
				curve_cap
			)
		if carried:
			carry_rival(i, rival, target_lane, target_speed, dt)
			continue
		rival.world_reverse_cooldown = maxf(0, rival.world_reverse_cooldown - dt)
		var reversing_cpu: float = maxf(0, rival.world_reverse - dt)
		var stuck: float = (
			rival.world_stuck + dt if body.grounded and now < 1.5 and (blocked or target_speed > 5) else 0.0
		)
		if stuck > 1.25 and reversing_cpu <= 0 and rival.world_reverse_cooldown <= 0 and rival_rear_clear(i):
			reversing_cpu = 1.0
			rival.world_reverse_cooldown = 4.0
			rival.world_reverse_axis = (
				-signf(target_lane - float(rival.lane)) * 0.65
				if absf(rival.lane) < race.track.half_width(d) - 3
				else 0.0
			)
			stuck = 0
		rival.world_stuck = stuck
		rival.world_reverse = reversing_cpu
		var signed_speed: float = body.velocity.dot(forward)
		var acceleration: float = rival.specification.boost_accel if used_nitro else rival.specification.accel
		if body.grounded:
			acceleration *= Corner.engine_factor(now, target_speed, body.corner_demand, body.corner_grip)
		var must_brake: bool = blocked or curve_cap < now or dirt > .01 or absf(angle) > 1.1
		var desired: float = (
			move_toward(now, target_speed, rival.specification.brake * dt)
			if target_speed < now and must_brake
			else Power.target(now, target_speed, acceleration, dt, true, dirt)
		)
		if reversing_cpu > 0:
			# A bounded physical manoeuvre, never a curve reposition or teleport.
			# Check rear clearance again every frame as other traffic keeps moving.
			if not rival_rear_clear(i):
				rival.world_reverse = 0
				desired = 0
			else:
				desired = move_toward(signed_speed, -7, rival.specification.brake * dt)
				axis = float(rival.world_reverse_axis)
		elif signed_speed < -0.5:
			desired = move_toward(signed_speed, 0, rival.specification.brake * dt)
		body.road_heading = (race.track.point(d + 2) - race.track.point(d - 2)).normalized()
		body.advance(
			dt,
			axis,
			desired,
			false,
			(
				rival.surface.grip_factor
				* lerpf(1, 0.72, dirt)
				* preload("res://scripts/track/harbor_corridor.gd").grip(race.track.active, d)
			)
		)
		var old := Vector2(rival.lane, rival.distance)
		var data: Dictionary = trackers[i].update(body.feet_position(), dt)
		rival.distance = data.distance
		rival.lane = data.lane
		rival.speed = speed_of(body)
		rival.air.active = not body.grounded
		rival.air.height = maxf(0, body.feet_position().y - race.track.point(rival.distance, rival.lane).y)
		rival.air.velocity = body.velocity.y
		rival.drifting = false
		if body.grounded and not was_airborne and data.valid:
			for event in rival.surface.contact(
				race.track.active, old, Vector2(rival.lane, rival.distance), rival.speed
			):
				if event == "water":
					body.velocity *= 0.96
		rival.boosting = rival.surface.pad_time > 0 or rival.nitro_active
		if body.feet_position().y < race.track.point(d).y - 8:
			recover_body(i, d, 0)


# Beyond the guardrail line there is no road to drive on: after a moment the car is put
# back on the last safe stretch, whatever launched it over the rail.
func update_outside(delta: float) -> void:
	var side := signf(race.lane)
	var edge: float = race.track.half_width(race.distance) + race.track.active.rail_setback(race.distance, side) + 1.2
	outside_time = outside_time + delta if absf(race.lane) > edge else 0.0
	if fork_area():
		outside_time = 0
	if outside_time > 1.0:
		outside_time = 0.0
		race.return_to_road()


func update_recovery(delta: float, data: Dictionary) -> void:
	if race.mode == "tour" and race.track.in_fork_gap(player_body.feet_position(), race.distance):
		recovery_clock = 0
		race.return_to_road()
		return
	update_outside(delta)
	if data.valid and player_body.grounded and absf(race.lane) < race.track.half_width(race.distance) - 1:
		safe_distance = race.distance
		safe_lane = race.lane
	var below: float = race.track.point(race.distance, race.lane).y - player_body.feet_position().y
	var offscreen: bool = (
		below > 3
		and player_body.velocity.y < -1
		and not race.camera.is_position_in_frustum(player_body.global_position)
	)
	var fallen: bool = below > 8 or offscreen
	recovery_clock = recovery_clock + delta if fallen else 0.0
	if recovery_clock > 0.15:
		recovery_clock = 0
		race.return_to_road()


# 자동·수동·상대 차량 복구에 같은 실제 노면 검사를 적용한다.
func recover_body(index: int, d: float, lane: float) -> Dictionary:
	var site := RoadRecovery.find(race, bodies[index], d, lane)
	if site.is_empty():
		return {}
	teleport(index, site.distance, site.lane, false)
	bodies[index].reset_pose(site.feet, site.forward, site.up)
	bodies[index].velocity = site.forward * RoadRecovery.RESUME_SPEED
	bodies[index].grounded = true
	if index == 0:
		race.speed = RoadRecovery.RESUME_SPEED
	else:
		race.rivals[index - 1].speed = RoadRecovery.RESUME_SPEED
	return site


func recover_player() -> bool:
	# 검사가 실패하면 현재 위치를 유지하고 검증하지 않은 저장 좌표로 이동하지 않는다.
	var site := recover_body(0, safe_distance, safe_lane)
	if site.is_empty():
		return false
	# 성공한 복구만 여기서 한 번 집계해 모든 호출 경로의 보상·기록을 함께 무효화한다.
	race.personal_run.invalidate()
	race.route_challenges.invalidate()
	race.rewards.cancel_drift()
	race.rewards.exit_boost = 0
	race.rewards.break_pass_chain()
	safe_distance = site.distance
	safe_lane = site.lane
	race.lane_velocity = 0
	race.slip_angle = 0
	race.offroad_amount = 0
	race.steer = 0
	reverse_wait = 0
	reversing = false
	recovery_clock = 0
	race.tire_trails.reset()
	race.player.reset_driving_effects()
	race.cancel_nitro()
	race.protection_left = 3.0
	player_body.collision_layer = 16
	player_body.collision_mask = 3
	race.player.set_protection(true)
	place_cars()
	race.camera_offset = -site.forward * 7.1 + Vector3.UP * 3
	update_camera(1)
	race.player.reset_physics_interpolation()
	race.camera.reset_physics_interpolation()
	return true


func update_protection(delta: float) -> void:
	var was: bool = race.protection_left > 0
	race.protection_left = maxf(0, race.protection_left - delta)
	if was and race.protection_left <= 0:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = player_body.contact_shape.shape
		query.transform = player_body.global_transform
		query.collision_mask = 12
		query.exclude = [player_body.get_rid()]
		# 보호 종료 순간 장애물 내부나 사라진 노면 위에 남겨 두지 않는다.
		if player_body.rescue_floor_used or not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			if recover_body(0, race.distance, race.lane).is_empty():
				race.protection_left = .1
	var active: bool = race.protection_left > 0
	var layer := 16 if active else 4
	var mask := 3 if active else 15
	if player_body.collision_layer != layer:
		player_body.collision_layer = layer
	if player_body.collision_mask != mask:
		player_body.collision_mask = mask
	player_body.rescue_floor.clear()
	if active:
		var side := signf(race.lane)
		var edge: float = race.track.half_width(race.distance) + race.track.active.rail_setback(race.distance, side)
		if absf(race.lane) < edge - 1.05:
			player_body.rescue_floor = {
				"position": race.track.point(race.distance, race.lane), "normal": road_up(race.distance)
			}
	race.player.set_protection(active)


func update_camera(delta: float) -> void:
	if race.state == RaceState.PAUSED:
		return
	var forward: Vector3 = player_body.forward_direction()
	if player_body.coast_slide > .01 and player_body.velocity.length() > 25:
		forward = forward.lerp(player_body.velocity.normalized(), 0.65 * player_body.coast_slide).normalized()
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	var pace := clampf(race.speed / 88, 0, 1)
	var up := Vector3.UP.lerp(player_body.surface_normal, 0.3).normalized()
	var preview: bool = race.state == RaceState.RACING and player_body.grounded and not race.crash.active
	var angle := camera_state.preview_angle(race, forward) if preview and not race.motion_reduced else 0.0
	camera_state.advance(delta, race.speed, angle, race.player.body_motion.acceleration.x, preview, race.motion_reduced)
	var sight := forward.rotated(Vector3.UP, camera_state.look_yaw).normalized()
	var desired: Vector3 = -forward * (7.1 + pace * 0.9) + Vector3.UP * (3.0 + race.camera_intro * 1.5)
	desired -= forward * camera_state.pullback
	if not race.motion_reduced and race.state == RaceState.RACING:
		# Speed hum, kerb/rail rumble, boost pull-back and a dip when the car lands.
		race.camera_time += delta
		var jitter: float = 0.010 * pace * pace + race.edge_rumble * pace * 0.03 + race.offroad_amount * pace * 0.02
		desired += right * sin(race.camera_time * 53) * jitter + Vector3.UP * cos(race.camera_time * 67) * jitter * 0.55
		var heat: float = race.player.boost_fx.heat if race.player.boost_fx != null else 0.0
		desired += -forward * (race.boost_kick * .55 + heat * .35)
		desired.y -= race.air.landing_flash * race.air.landing_strength * 0.4
	race.camera_intro = maxf(0, race.camera_intro - delta * 0.8)
	race.camera_offset = race.camera_offset.lerp(desired, 1 - exp(-delta * 7))
	var recoil: Vector3 = race.collision_camera_offset(forward, right)
	race.camera.position = race.player.position + race.camera_offset + recoil
	if race.crash.active:
		var origin: Vector3 = race.player.position + Vector3.UP * 0.8
		var query := PhysicsRayQueryParameters3D.create(origin, race.camera.position, 2, [player_body.get_rid()])
		var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and origin.distance_to(obstruction.position) > 1:
			race.camera.position = obstruction.position + obstruction.normal * 0.2
	race.camera.look_at(race.player.position + sight * (5.0 + pace * 3.0) + up * 0.8, up)
	var fov: float = 68 if race.motion_reduced else 66 + pace * 17 + (6 if race.boosting else 0)
	if not race.motion_reduced and race.boosting and race.player.boost_fx != null:
		fov += race.player.boost_fx.heat * 2.5
	race.camera.fov = lerpf(race.camera.fov, fov, 1 - exp(-delta * 5))


func fork_area() -> bool:
	return (
		race.mode == "tour"
		and (
			race.distance > race.track.length - 5
			or (
				race.distance < preload("res://scripts/track/route_library.gd").FORK_RECONSIDER + 5
				and is_instance_valid(race.track.sibling)
			)
		)
	)
