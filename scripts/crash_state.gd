extends RefCounted
# A short arcade tumble; world-space launch and contacts remain in the motor.
var active := false
var elapsed := 0.0
var duration := 1.25
var direction := 1.0
var visual_roll := 0.0
var visual_pitch := 0.0
func start(speed: float, normal: Vector2, _ground_y: float = 0) -> void:
	if active: return
	active = true
	elapsed = 0
	duration = lerpf(1.05,1.4,clampf((speed-55)/55,0,1))
	direction = signf(normal.x) if absf(normal.x) > 0.1 else 1.0
	visual_roll = 0
	visual_pitch = 0
func advance(delta: float) -> bool:
	if not active: return false
	elapsed += delta
	var phase := clampf(elapsed/duration,0,1)
	visual_roll = direction*TAU*smoothstep(0,1,phase)
	visual_pitch = sin(phase*PI)*0.7
	if phase < 1: return false
	reset()
	return true
func reset() -> void:
	active = false
	elapsed = 0
	visual_roll = 0
	visual_pitch = 0
