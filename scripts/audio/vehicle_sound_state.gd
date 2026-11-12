extends RefCounted
# 물리 틱에서만 갱신한다. 웹·네이티브 믹서와 시각 차체가 같은 변속 순간을 읽는다.
var load_amount := .55
var gear := 0
var candidate := 0
var candidate_time := 0.0
var shift := 0.0
var last_reward := 0
var reward_pitch := 1.0


func reset() -> void:
	load_amount = .55
	gear = 0
	candidate = 0
	candidate_time = 0
	shift = 0
	last_reward = 0
	reward_pitch = 1


func advance(race: Node3D, delta: float) -> void:
	if delta <= 0:
		return
	var force: float = race.player.body_motion.acceleration.x
	var target := clampf(.72 + force * .012, .55, 1.0) if race.throttling else .12
	load_amount = lerpf(load_amount, target, 1 - exp(-delta * 12))
	shift = move_toward(shift, 0, delta * 6)
	var next: int = maxi(1, race.gear_number())
	if gear == 0 or race.speed < 8 or abs(next - gear) > 1:
		gear = next
		candidate_time = 0
	elif next != gear:
		var band: float = race.vehicle.max_speed / 5.8
		var boundary: float = mini(next, gear) * band
		var beyond: bool = race.speed > boundary + .6 if next > gear else race.speed < boundary - .6
		candidate_time = candidate_time + delta if next == candidate and beyond else 0.0
		candidate = next
		if candidate_time >= .06:
			shift = 1.0 if next > gear else -.45
			gear = next
			candidate_time = 0
	else:
		candidate_time = 0
	if race.rewards.event_id > last_reward:
		reward_pitch = 1.0 + .07 * (race.rewards.event_chain - 1)
		race.boost_kick = maxf(race.boost_kick, .28 if race.rewards.event_boost else .12)
		race.haptics.pulse(.18, .42, .1, 2)
	last_reward = race.rewards.event_id
