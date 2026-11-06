extends RefCounted
const WAIT_SECONDS := 4.0
const MIN_MOVEMENT := 3.0
var anchor := Vector3.INF
var stopped_time := 0.0
var available := false
func reset(at: Vector3 = Vector3.INF) -> void:
	anchor = at
	stopped_time = 0
	available = false
func advance(delta: float, at: Vector3) -> void:
	# A trapped car bobbing or tumbling vertically still needs a rescue.
	if not anchor.is_finite() or Vector2(anchor.x-at.x,anchor.z-at.z).length() >= MIN_MOVEMENT:
		reset(at)
		return
	stopped_time += maxf(0,delta)
	available = stopped_time >= WAIT_SECONDS
