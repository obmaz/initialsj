extends RefCounted
# 광고의 +Z 정면을 접근 차량과 도로 중심 쪽으로 기울인다.
static func yaw(road: Node3D, distance: float, lane: float) -> float:
	var toward: Vector3 = road.point(distance-65)-road.point(distance,lane)
	var base: float = road.heading(distance)
	return base+clampf(wrapf(atan2(toward.x,toward.z)-base,-PI,PI),-.38,.38)
