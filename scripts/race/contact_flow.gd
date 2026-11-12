extends RefCounted
# 가벼운 접촉의 유예와 실제 벽 충돌에서 이어지는 지속 밀어붙이기를 구분한다.
var reward_hold := 0.0
var wall_seconds := 0.0
var wall_latched := false


func reset() -> void:
	reward_hold = 0
	wall_seconds = 0
	wall_latched = false


func contact(barrier: bool) -> void:
	reward_hold = .18
	wall_latched = wall_latched or barrier


func advance(delta: float, pressed_to_wall: bool) -> void:
	reward_hold = maxf(0, reward_hold - delta)
	if wall_latched and pressed_to_wall:
		wall_seconds += delta
		reward_hold = maxf(reward_hold, .12)
	else:
		wall_latched = false
		wall_seconds = 0


func sustained() -> bool:
	return wall_seconds >= .3
