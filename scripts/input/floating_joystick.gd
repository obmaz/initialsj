extends RefCounted
# 첫 포인터만 조향을 소유한다. 새로 누른 위치를 중립으로 삼고 손을 떼면 즉시 해제한다.
const NO_POINTER := -99999
var pointer := NO_POINTER
var origin := Vector2.ZERO
var offset := Vector2.ZERO
var travel := 58.0


func active() -> bool:
	return pointer != NO_POINTER


func begin(index: int, at: Vector2, radius: float) -> bool:
	if active():
		return false
	pointer = index
	origin = at
	offset = Vector2.ZERO
	travel = radius
	return true


func move(index: int, at: Vector2) -> void:
	if index == pointer:
		offset = (at - origin).limit_length(travel)


func release(index: int) -> void:
	if index == pointer:
		reset()


func reset() -> void:
	pointer = NO_POINTER
	offset = Vector2.ZERO


func axis() -> float:
	var value := offset.x / maxf(1, travel)
	return signf(value) * maxf(0, (absf(value) - .06) / .94) if active() else 0.0
