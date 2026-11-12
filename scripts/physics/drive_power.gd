extends RefCounted
# 가속 출력과 초과 속도 항력을 분리한다. 제동·접지·접촉은 호출자가 적용한다.
const COAST_DRAG := 5.0


static func target(
	speed: float, cap: float, acceleration: float, delta: float, throttle: bool, dirt: float = 0
) -> float:
	if not throttle:
		return maxf(0, speed - (COAST_DRAG + clampf(dirt, 0, 1) * 18) * delta)
	if speed <= cap:
		return move_toward(speed, cap, maxf(0, acceleration) * delta)
	var drag := minf(COAST_DRAG, 2.4 + (speed - cap) * .12)
	# 코스 밖을 부스트 관성으로 가로지르는 이득은 주지 않는다.
	drag += clampf(dirt, 0, 1) * 18
	return move_toward(speed, cap, drag * delta)
