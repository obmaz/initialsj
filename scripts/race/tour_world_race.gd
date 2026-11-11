extends "res://scripts/race/world_race.gd"
# 투어도 트랙과 같은 실제 차체를 사용하며 분기와 제한시간만 별도로 관리한다.
const Library = preload("res://scripts/track/route_library.gd")
const Features = preload("res://scripts/track/road_features.gd")


func assisted_axis(manual: float) -> float:
	if race.route_preference < 0 or not race.route_choices_visible() or race.distance < race.track.length - 170:
		return manual
	if absf(manual) > 0.2:
		race.route_preference = -1
		return manual
	var look := clampf(race.speed * 0.85, 28, 65)
	var lane := -2.0 if race.route_preference == 0 else 2.0
	var target: Vector3 = race.track.traffic_point(race.distance + look, lane, race.route_preference)
	var forward: Vector3 = player_body.forward_direction()
	var right := Vector3(-forward.z, 0, forward.x).normalized()
	var direction: Vector3 = target - player_body.feet_position()
	var angle := atan2(direction.dot(right), direction.dot(forward))
	var wheel: float = (
		(0.46 + race.vehicle.handling * 0.007) / (1 + race.speed * 0.035) * WorldCar.steering_scale(race.speed)
	)
	return clampf(atan(5.4 * sin(angle) / look) / wheel, -0.65, 0.65)


func step(
	delta: float, axis: float, drift_input: bool, gas: bool, brake: bool, nitro_input: bool, cell_input: bool
) -> void:
	delta = minf(delta, race.time_left)
	if delta <= 0:
		fail_run()
		return
	var before: float = race.distance
	race.time_left = maxf(0, race.time_left - delta)
	for field in ["route_choice_flash", "route_confirm_flash"]:
		race.set(field, maxf(0, float(race.get(field)) - delta))
	super.step(delta, assisted_axis(axis), drift_input, gas, brake, nitro_input, cell_input)
	race.hazard_text = Features.hazard_ahead(race.track.active, race.distance)
	var data: Dictionary = trackers[0].sample(player_body.feet_position(), race.distance)
	if (
		data.valid
		and race.stage_index < Library.STAGES - 1
		and before < race.track.active.checkpoint_distance()
		and race.distance >= race.track.active.checkpoint_distance()
	):
		race.award_checkpoint()
	if data.valid and race.stage_index == Library.STAGES - 1 and race.distance >= race.track.length:
		race.finish()
		return
	if race.time_left <= 0:
		fail_run()
		return
	var changed := false
	if (
		data.valid
		and race.stage_index < Library.STAGES - 1
		and race.distance >= race.track.length + Library.FORK_COMMIT
	):
		race.advance_route()
		changed = true
	elif race.distance < 150 and is_instance_valid(race.track.sibling):
		var reconsidered: Dictionary = race.track.reconsider(race.distance, race.lane)
		if not reconsidered.is_empty():
			race.distance = reconsidered.distance
			race.lane = reconsidered.lane
			race.route_confirm_title = race.route_banner()
			changed = true
	if changed:
		# 차체의 world transform·속도·공중 상태는 보존하고 계측 기준만 바꾼다.
		trackers[0].reposition(race.distance)
		var projection: Dictionary = trackers[0].sample(player_body.feet_position(), race.distance)
		race.distance = projection.distance
		race.lane = projection.lane
		trackers[0].reposition(race.distance)
		safe_distance = maxf(3, race.distance)
		safe_lane = clampf(race.lane, -3, 3)
		race.surface.reset()
	race.track.maintain(race.distance)


func fail_run() -> void:
	if race.state == RaceState.FAILED:
		return
	race.state = RaceState.FAILED
	race.personal_run.finish(race, false)
	race.cancel_nitro()
	race.drifting = false
	race.boosting = false
