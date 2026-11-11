extends RefCounted
# 코스 전용 호수·잔디. 도로와 호수 위를 같은 높이의 평면으로 덮지 않는다.
const CENTER := Vector2(-31.2, -177.45)
const HALF_SIZE := Vector2(374.4, 99.45)
const SHORE := 8.0
const BASE_HEIGHT := 6.5
const WATER_HEIGHT := 6.32
const SEGMENTS := 96


static func outline(angle: float, extra: float = 0) -> Vector2:
	var c := cos(angle)
	var s := sin(angle)
	return CENTER + Vector2(signf(c) * sqrt(absf(c)), signf(s) * sqrt(absf(s))) * (HALF_SIZE + Vector2.ONE * extra)


static func contains(point: Vector3) -> bool:
	var q := (Vector2(point.x, point.z) - CENTER).abs() / (HALF_SIZE + Vector2.ONE * SHORE)
	return pow(q.x, 4) + pow(q.y, 4) <= 1
