extends RefCounted
# 항만 뒤쪽 직선의 컨테이너 사이 작업 통로. 양끝140m에서 두 차선으로 좁혀진다.
const SPAN := Vector2(1300, 1750)
const CORE := Vector2(1440, 1610)
const HALF_WIDTH := 4.2


static func weight(distance: float) -> float:
	return smoothstep(SPAN.x, CORE.x, distance) * (1 - smoothstep(CORE.y, SPAN.y, distance))


static func contains(section: Node3D, distance: float) -> bool:
	var d := fposmod(distance, section.length)
	return section.closed_loop and section.course_id == 2 and d >= SPAN.x and d <= SPAN.y


static func grip(section: Node3D, distance: float) -> float:
	return (
		lerpf(1.0, .82, weight(fposmod(distance, section.length)))
		if section.closed_loop and section.course_id == 2
		else 1.0
	)
