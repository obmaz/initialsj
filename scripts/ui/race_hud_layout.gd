extends RefCounted
# 투어·트랙이 공유하는 콘텐츠 좌표. OS 안전 영역 변환은 MenuLayout이 담당한다.
const DESIGN := Vector2(1280, 720)
const EDGE := 16.0
const GAP := 16.0
const PAUSE := Rect2(16, 16, 64, 64)
const COURSE := Rect2(100, 16, 292, 58)
const STATS := Rect2(408, 16, 616, 58)
const MINIMAP := Rect2(1080, 16, 184, 184)
const MAP_RADIUS := 76.0
const MAP_INSET := 7.0
const STICK_RADIUS := 90.0
const STICK_TRAVEL := 72.0
const CONTROL_Y := 607.0


static func top_rects(area: Rect2) -> Dictionary:
	var pause := Rect2(area.position + Vector2.ONE * EDGE, PAUSE.size)
	var course := Rect2(pause.position + Vector2(pause.size.x + GAP, 0), COURSE.size)
	var minimap := Rect2(Vector2(area.end.x - EDGE - MINIMAP.size.x, pause.position.y), MINIMAP.size)
	var stats := Rect2(course.position + Vector2(course.size.x + GAP, 0), STATS.size)
	stats.size.x = minimap.position.x - GAP - stats.position.x
	return {"pause": pause, "course": course, "stats": stats, "minimap": minimap}


static func route_point(row: int, node: int, rect: Rect2 = MINIMAP) -> Vector2:
	# 보이지 않는 프레임 중심 대신 실제 경로의 위·오른쪽 외곽을 상단 HUD에 맞춘다.
	return (
		Vector2(rect.end.x - MAP_INSET, rect.position.y + MAP_INSET)
		+ Vector2((node - row * .5 - 2) * 28, (4 - row) * 24)
	)


static func project_map(point: Vector2, bounds: Rect2, rect: Rect2 = MINIMAP) -> Vector2:
	# 기존 축척·코스 비율을 유지하면서 실제 도로선의 위·오른쪽을 고정한다.
	var extent := maxf((bounds.size * .5).length(), 1)
	var scale_factor := MAP_RADIUS / extent
	var span := bounds.size * scale_factor
	var origin := Vector2(rect.end.x - MAP_INSET - span.x, rect.position.y + MAP_INSET)
	return origin + (point - bounds.position).clamp(Vector2.ZERO, bounds.size) * scale_factor


static func steering_zone(mirrored: bool) -> Rect2:
	return Rect2(920 if mirrored else 100, 484, 260, 136)


static func steering_rest(mirrored: bool) -> Vector2:
	return Vector2(1131 if mirrored else 149, CONTROL_Y)
