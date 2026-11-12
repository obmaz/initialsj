extends RefCounted
# 시선·거리의 작은 보정만 보유한다. 물리 방향과 카메라 충돌 처리는 공통 주행이 소유한다.
const MAX_LOOK := .20
var look_yaw := 0.0
var look_velocity := 0.0
var pullback := 0.0


func reset() -> void:
	look_yaw = 0
	look_velocity = 0
	pullback = 0


func advance(delta: float, speed: float, road_angle: float, acceleration: float, enabled: bool, reduced: bool) -> void:
	if delta <= 0:
		return
	var dt := minf(delta, .1)
	var target := (
		clampf(road_angle * .65, -MAX_LOOK, MAX_LOOK) * smoothstep(8, 35, speed) if enabled and not reduced else 0.0
	)
	# 임계 감쇠의 해를 사용해 프레임 간격이 커져도 오버슈트하지 않는다.
	var offset := look_yaw - target
	var change := (look_velocity + 8 * offset) * dt
	var decay := exp(-8 * dt)
	look_yaw = target + (offset + change) * decay
	look_velocity = (look_velocity - 8 * change) * decay
	var distance_target := clampf(acceleration / 30, -1, 1) * .32 if enabled and not reduced else 0.0
	pullback = lerpf(pullback, distance_target, 1 - exp(-dt * 5))
	if reduced:
		reset()


func preview_angle(race: Node3D, forward: Vector3) -> float:
	var section: Node3D = race.track.active
	var d: float = (
		fposmod(race.distance, section.length) if section.closed_loop else clampf(race.distance, 0, section.length)
	)
	var ahead: float = d + clampf(race.speed * 1.15, 25, 110)
	if not section.closed_loop:
		# 아직 선택하지 않은 두 갈래의 평균 위치를 시선 목표로 쓰지 않는다.
		ahead = minf(ahead, section.length)
	if ahead - d < 4:
		return 0
	var road: Vector3 = (section.point(ahead, race.lane) - section.point(d, race.lane)).slide(Vector3.UP).normalized()
	var travel := forward.slide(Vector3.UP).normalized()
	if road.length_squared() < .5 or travel.dot(road) < .3:
		return 0
	return travel.signed_angle_to(road, Vector3.UP)
