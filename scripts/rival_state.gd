extends RefCounted
# 상대 차량의 초기 상태만 만든다. 주행·접촉 판단은 world_race.gd의 실제 차체가 담당한다.
const SurfaceState = preload("res://scripts/road_surface_state.gd")
const AirState = preload("res://scripts/air_state.gd")
static func initialize(rivals: Array[Dictionary]) -> void:
	for i in range(rivals.size()):
		var r: Dictionary = rivals[i]
		r.id = i
		r.active = i < 8
		r.distance = 150.0 + i * 57
		r.speed = 32.0 + (i % 5) * 4
		r.pace = float(r.speed)
		r.lane = [-6.0,-2.0,2.0,6.0][i % 4]
		r.target_lane = float(r.lane)
		r.decision = i * 0.07
		r.surface = SurfaceState.new()
		r.air = AirState.new()
		r.boosting = false
		r.drifting = false
