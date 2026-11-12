extends RefCounted
# 물리 상태를 읽는 고정 크기 신호. 새 파티클·렌더 자원·이벤트 큐를 만들지 않는다.
const RaceState = preload("res://scripts/race/race_state.gd")
var grip_pressure := 0.0
var boost_envelope := 0.0
var warning_wait := 0.0
var warning_armed := true


func reset() -> void:
	grip_pressure = 0
	boost_envelope = 0
	warning_wait = 0
	warning_armed = true


func advance(race: Node3D, delta: float) -> void:
	if delta <= 0:
		return
	if race.state != RaceState.RACING:
		reset()
		return
	var body: CharacterBody3D = race.world_race.player_body
	var valid: bool = body.grounded and not race.crash.active and race.protection_left <= 0 and race.impact < .15
	var demand: float = body.corner_demand / maxf(body.corner_grip, 1) if valid and race.speed > 25 else 0.0
	grip_pressure = lerpf(grip_pressure, smoothstep(.6, 1.1, demand), 1 - exp(-delta * 12))
	warning_wait = maxf(0, warning_wait - delta)
	if grip_pressure < .25:
		warning_armed = true
	if (
		warning_armed
		and warning_wait <= 0
		and grip_pressure > .65
		and not race.drifting
		and valid
		and race.world_race.contact_flow.reward_hold <= 0
	):
		if not race.motion_reduced:
			race.haptics.pulse(.1, .2, .07, 1)
		warning_armed = false
		warning_wait = 1.2
	var target := 1.0 if race.boosting and valid and race.throttling else 0.0
	boost_envelope = lerpf(boost_envelope, target, 1 - exp(-delta * (12 if target > boost_envelope else 6)))
	if not valid or race.braking or race.drifting or not race.throttling:
		boost_envelope = 0
