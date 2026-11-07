extends RefCounted
# A rail hit above LAUNCH_SPEED always throws the car. The faster the hit, the higher it goes,
# the longer it stays up and the more it rolls and flips. World-space launch and contacts
# remain in the motor; this only drives the visual tumble.
const LAUNCH_SPEED := 45.0
const MAX_SPEED := 100.0
var active := false
var elapsed := 0.0
var duration := 1.25
var direction := 1.0
var rolls := 1.0
var flips := 0.0
var visual_roll := 0.0
var visual_pitch := 0.0

# 0 at the launch threshold, 1 at full speed.
static func severity(speed: float) -> float:
	return clampf((speed-LAUNCH_SPEED)/(MAX_SPEED-LAUNCH_SPEED),0,1)

static func launches(incoming_speed: float) -> bool:
	return incoming_speed >= LAUNCH_SPEED

# Upward launch speed for a hit; the hang time follows from gravity.
static func launch_up(incoming_speed: float) -> float:
	return lerpf(9.0,19.0,severity(incoming_speed))

func start(speed: float, normal: Vector2, _ground_y: float = 0, air_time: float = 0.0) -> void:
	if active: return
	var s := severity(speed)
	active = true
	elapsed = 0
	duration = clampf(air_time,0.8,2.2) if air_time > 0 else lerpf(1.0,1.9,s)
	direction = signf(normal.x) if absf(normal.x) > 0.1 else 1.0
	rolls = 1.0 if s < 0.34 else (2.0 if s < 0.7 else 3.0)
	flips = 0.0 if s < 0.5 else (1.0 if s < 0.85 else 2.0)
	visual_roll = 0
	visual_pitch = 0
func advance(delta: float) -> bool:
	if not active: return false
	elapsed += delta
	var phase := clampf(elapsed/duration,0,1)
	visual_roll = direction*TAU*rolls*smoothstep(0,1,phase)
	visual_pitch = sin(phase*PI)*0.7+TAU*flips*smoothstep(0.08,0.92,phase)
	if phase < 1: return false
	reset()
	return true
func reset() -> void:
	active = false
	elapsed = 0
	visual_roll = 0
	visual_pitch = 0
