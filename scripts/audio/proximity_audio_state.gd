extends RefCounted
# 실제 상대 위치만 관측한다. 차량 노드 참조·음원 큐·추월 점수는 보유하지 않는다.
const MAX_OBSERVATIONS := 32
const RaceState = preload("res://scripts/race/race_state.gd")
var observations: Dictionary = {}
var serial := 0
var pass_level := 0.0
var pass_pan := 0.0
var pass_pitch := 1.0
var pass_source := 0
var pass_age := 1.0
var draft_level := 0.0
var draft_pan := 0.0
var draft_pitch := 1.0
var active := false
var clock := 0.0
var stamp := 0
var pass_gap := 0.0
var best_pass := 0.0
var draft_weight := 0.0
var target_draft_pan := 0.0


func reset() -> void:
	observations.clear()
	serial += 1
	pass_level = 0
	pass_pan = 0
	pass_pitch = 1
	pass_source = 0
	pass_age = 1
	draft_level = 0
	draft_pan = 0
	draft_pitch = 1
	active = false
	clock = 0
	pass_gap = 0
	best_pass = 0
	draft_weight = 0
	target_draft_pan = 0


func update(race: Node3D, delta: float) -> void:
	if delta <= 0:
		return
	var player: CharacterBody3D = race.world_race.player_body
	var valid: bool = (
		race.state == RaceState.RACING
		and player.grounded
		and not race.crash.active
		and race.protection_left <= 0
		and race.speed > 15
		and player.velocity.dot(player.forward_direction()) > 10
	)
	if not valid:
		if active:
			reset()
		return
	active = true
	clock += delta
	stamp += 1
	pass_gap = maxf(0, pass_gap - delta)
	pass_age += delta
	pass_pitch = lerpf(1.15, .85, smoothstep(0, .45, pass_age))
	if pass_age > .8:
		pass_level = 0
	best_pass = 0
	draft_weight = 0
	target_draft_pan = 0
	var forward := player.velocity.slide(player.surface_normal).normalized()
	var right := forward.cross(player.surface_normal).normalized()
	var listener_right: Vector3 = race.camera.global_basis.x
	for i in range(1, race.world_race.bodies.size()):
		if race.rivals[i - 1].active:
			observe_body(race.world_race.bodies[i], player, forward, right, listener_right, delta)
	if race.mode == "tour":
		for other in race.get_tree().get_nodes_in_group("tour_road_traffic"):
			if other.clock == race and other.activated and other.road.visible:
				observe_body(other, player, forward, right, listener_right, delta)
	for id in observations.keys():
		if observations[id].stamp != stamp:
			observations.erase(id)
	if best_pass > 0 and pass_gap <= 0:
		serial += 1
		pass_level = best_pass
		pass_age = 0
		pass_pitch = 1.15
		pass_gap = .18
	var target: float = (
		.055 * draft_weight * smoothstep(.1, .8, race.draft_charge) * smoothstep(15, 45, race.speed)
		if race.drafting and race.throttling
		else 0.0
	)
	draft_level = lerpf(draft_level, target, 1 - exp(-delta * 8))
	draft_pan = lerpf(draft_pan, target_draft_pan, 1 - exp(-delta * 6))
	draft_pitch = .85 + clampf(race.speed / 90, 0, 1) * .3


func observe_body(
	other: CharacterBody3D,
	player: CharacterBody3D,
	forward: Vector3,
	right: Vector3,
	listener_right: Vector3,
	delta: float
) -> void:
	if not other.grounded:
		return
	var relative: Vector3 = other.feet_position() - player.feet_position()
	if relative.length_squared() > 70 * 70 or absf(relative.dot(player.surface_normal)) > 2.5:
		return
	var ahead := relative.dot(forward)
	var side := absf(relative.dot(right))
	var pan := clampf(relative.dot(listener_right) / maxf(relative.length(), 1) * 1.15, -.9, .9)
	var id := other.get_instance_id()
	observe(id, ahead, side, (player.velocity - other.velocity).dot(forward), pan, delta)


# 스칼라 관측 계약은 실제 차체 어댑터와 분리해 고저차·리스폰·중복 조건을 검사한다.
func observe(id: int, ahead: float, side: float, relative_speed: float, pan: float, delta: float) -> void:
	if not observations.has(id) and observations.size() >= MAX_OBSERVATIONS:
		return
	var record: Dictionary = (
		observations[id] if observations.has(id) else {"ahead": ahead, "stamp": stamp, "cooldown": 0.0}
	)
	var before: float = record.ahead
	var crossed := (before > 0 and ahead <= 0) or (before < 0 and ahead >= 0)
	var continuous := absf(ahead - before) <= absf(relative_speed) * delta * 2 + 1
	if (
		crossed
		and continuous
		and side > 2.1
		and side < 6
		and absf(ahead) < 5
		and absf(relative_speed) > 5
		and clock >= float(record.cooldown)
	):
		var level := .085 * (1 - smoothstep(2.5, 6, side)) * smoothstep(5, 30, absf(relative_speed))
		if level > best_pass and pass_gap <= 0:
			best_pass = level
			pass_pan = pan
			pass_source = id
		record.cooldown = clock + 1.2
	if id == pass_source and pass_age < .8:
		pass_pan = pan
	if ahead > 8 and ahead < 60 and side < 2.8:
		var weight := (1 - smoothstep(1, 2.8, side)) * (1 - smoothstep(35, 60, ahead))
		if weight > draft_weight:
			draft_weight = weight
			target_draft_pan = clampf(pan, -.3, .3)
	record.ahead = ahead
	record.stamp = stamp
	observations[id] = record
