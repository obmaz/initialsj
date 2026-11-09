extends RefCounted
# 열린 투어 도로의 계측. 실제 차체를 곡선으로 이동시키거나 고정하지 않는다.
var section: Node3D
var distance := 80.0
var lane := 0.0
var previous_world := Vector3.ZERO
var has_previous_world := false

func configure(road: Node3D) -> void:
	section = road
	reset()

func reset(d: float = 80.0) -> void:
	distance = d
	lane = 0
	has_previous_world = false

func reposition(d: float) -> void:
	reset(d)

func sample(world: Vector3, hint: float) -> Dictionary:
	var d := hint
	# 진행 방향의 투영만 보정하므로 겹치는 교량·반대 분기로 건너뛰지 않는다.
	for iteration in range(8):
		var center: Vector3 = section.point(d)
		var tangent: Vector3 = section.point(d+1)-section.point(d-1)
		tangent.y = 0
		var residual := (world-center).dot(tangent.normalized())
		d += clampf(residual/maxf(0.45,tangent.length()*0.5),-12,12)
		if absf(residual) < 0.015: break
	var forward: Vector3 = section.point(d+1)-section.point(d-1)
	forward.y = 0
	var right := Vector3(-forward.z,0,forward.x).normalized()
	var lateral: float = (world-section.point(d)).dot(right)
	var ground: Vector3 = section.point(d,lateral)
	var vertical := world.y-ground.y
	var width: float = section.half_width(d)
	var setback: float = section.active.rail_setback(d,signf(lateral))
	var valid := absf(lateral) <= width+setback+0.25 and vertical >= -2 and vertical <= 12
	return {"distance":d,"projection_distance":d,"lane":lateral,"valid":valid,"trackable":valid,"ground_height":ground.y,"vertical_error":vertical,"finished_laps":0}

func update(world: Vector3, delta: float = 1.0/60) -> Dictionary:
	var result := sample(world,distance)
	var plausible: bool = absf(float(result.distance)-distance) <= maxf(2,delta*160+1.5)
	if has_previous_world: plausible = plausible and world.distance_to(previous_world) <= maxf(4,delta*200+2)
	previous_world = world
	has_previous_world = true
	# 공중에서도 연속 위치를 추적한다. 보상은 유효한 높이와 노면에서만 허용한다.
	if plausible: distance = result.distance
	lane = result.lane
	result.distance = distance
	result.valid = result.valid and plausible
	result.trackable = result.trackable and plausible
	return result
