extends RefCounted
# 도로 진행 방향의 이동량으로 정체를 판단한다. 옆으로 밀리거나 뒤로 가도 정체가 풀리지 않는다.
const WAIT_SECONDS := 2.0
const MIN_MOVEMENT := 3.0
var anchor := Vector3.INF
var stopped_time := 0.0
var available := false


func reset(at: Vector3 = Vector3.INF) -> void:
	anchor = at
	stopped_time = 0
	available = false


func advance(delta: float, at: Vector3, forward: Vector3 = Vector3.RIGHT, heading_error: float = 0) -> void:
	var direction := forward.slide(Vector3.UP).normalized()
	if not anchor.is_finite() or (at - anchor).dot(direction) >= MIN_MOVEMENT:
		reset(at)
	else:
		stopped_time += maxf(0, delta)
	available = stopped_time >= WAIT_SECONDS or absf(heading_error) >= PI / 3
