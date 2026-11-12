extends RefCounted
# 실제 앞차를 따라 충전하고 같은 차 옆으로 빠져나와 통과했을 때만 성공한다.
# 대상은 ID로만 보유하며 점수·니트로는 기존 추월 규칙이 지급한다.
const RaceState = preload("res://scripts/race/race_state.gd")
var charge := 0.0
var ready := false
var window := 0.0
var target_id := 0
var passes := 0
var awarded: Dictionary = {}
var generation := ""
var before_ahead := NAN
var forward := Vector3.FORWARD


func reset() -> void:
	cancel()
	passes = 0
	awarded.clear()
	generation = ""


func cancel() -> void:
	charge = 0
	ready = false
	window = 0
	target_id = 0
	before_ahead = NAN


func clean(race: Node3D) -> bool:
	var player: CharacterBody3D = race.world_race.player_body
	var road: Vector3 = (race.track.point(race.distance + 3) - race.track.point(race.distance - 3)).normalized()
	return (
		race.state == RaceState.RACING
		and player.grounded
		and not race.crash.active
		and race.protection_left <= 0
		and race.speed > 25
		and player.velocity.dot(road) > 20
		and race.throttling
		and not race.braking
		and not race.drifting
		and race.impact < .15
		and race.impact_age > .6
		and race.offroad_amount < .15
	)


func wake_candidate(other: CharacterBody3D, player: CharacterBody3D) -> float:
	if not other.grounded or other.velocity.dot(forward) < 5:
		return INF
	var relative: Vector3 = other.feet_position() - player.feet_position()
	var ahead := relative.dot(forward)
	if ahead <= 8 or ahead >= 60 or absf(relative.dot(player.surface_normal)) > 2.5:
		return INF
	return ahead if relative.slide(player.surface_normal).cross(forward).length() < 2.4 else INF


func prepare(race: Node3D, delta: float) -> bool:
	if delta <= 0:
		return false
	var key := "%d:%d" % [race.stage_index, race.laps_completed]
	if key != generation:
		generation = key
		awarded.clear()
		cancel()
	var player: CharacterBody3D = race.world_race.player_body
	forward = player.forward_direction()
	before_ahead = NAN
	var wake: CharacterBody3D
	var nearest := INF
	if player.grounded and not race.crash.active and race.protection_left <= 0 and player.velocity.dot(forward) > 8:
		for i in range(1, race.world_race.bodies.size()):
			if not race.rivals[i - 1].active:
				continue
			var other: CharacterBody3D = race.world_race.bodies[i]
			var ahead := wake_candidate(other, player)
			if ahead < nearest:
				nearest = ahead
				wake = other
		if race.mode == "tour":
			for other in race.get_tree().get_nodes_in_group("tour_road_traffic"):
				if other.clock != race or not other.activated or not other.road.visible:
					continue
				var ahead := wake_candidate(other, player)
				if ahead < nearest:
					nearest = ahead
					wake = other
	var drafting := wake != null
	if not clean(race):
		cancel()
		return drafting
	if ready:
		window = 3.0 if wake != null and wake.get_instance_id() == target_id else maxf(0, window - delta)
		if window <= 0:
			cancel()
	elif wake != null and not awarded.has(wake.get_instance_id()):
		if target_id != wake.get_instance_id():
			charge = 0
			target_id = wake.get_instance_id()
		charge = minf(1, charge + delta / 1.1)
		ready = charge >= 1
		window = 3.0 if ready else 0.0
	else:
		charge = maxf(0, charge - delta * 2)
		if charge <= 0:
			cancel()
	if target_id != 0:
		var target = instance_from_id(target_id)
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.grounded:
			cancel()
		else:
			var relative: Vector3 = target.feet_position() - player.feet_position()
			if relative.length_squared() > 90 * 90 or absf(relative.dot(player.surface_normal)) > 2.5:
				cancel()
			else:
				before_ahead = relative.dot(forward)
	return drafting


func finish(race: Node3D, delta: float) -> void:
	if not ready or not is_finite(before_ahead):
		return
	if not clean(race):
		cancel()
		return
	var target = instance_from_id(target_id)
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.grounded:
		cancel()
		return
	var player: CharacterBody3D = race.world_race.player_body
	var relative: Vector3 = target.feet_position() - player.feet_position()
	var ahead := relative.dot(forward)
	var side := absf(relative.dot(forward.cross(player.surface_normal)))
	var closing: float = (player.velocity - target.velocity).dot(forward)
	if (
		before_ahead > 0
		and ahead <= 0
		and ahead > -10
		and side > 2.2
		and side < 7.5
		and absf(relative.dot(player.surface_normal)) < 2.5
		and closing > 1
		and absf(ahead - before_ahead) <= closing * delta * 2 + 1
	):
		awarded[target_id] = true
		passes += 1
		race.rewards.announce("SLIPSTREAM PASS", 1.4, 0, 4, maxi(1, race.rewards.pass_chain))
		cancel()
