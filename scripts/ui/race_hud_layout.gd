extends RefCounted
# 투어·트랙이 공유하는 콘텐츠 좌표. OS 안전 영역 변환은 MenuLayout이 담당한다.
const DESIGN := Vector2(1280, 720)
const EDGE := 24.0
const PAUSE := Rect2(24, 24, 64, 64)
const COURSE := Rect2(104, 24, 256, 64)
const STATS := Rect2(376, 24, 680, 64)
const MINIMAP := Rect2(1072, 24, 184, 184)
const MAP_RADIUS := 76.0


static func route_point(row: int, node: int) -> Vector2:
	return MINIMAP.get_center() + Vector2((node - row * .5) * 28, 48 - row * 24)


static func project_map(point: Vector2, bounds: Rect2) -> Vector2:
	# 직사각형의 모서리까지 원 안에 맞추고, 도로 밖 차량도 프레임을 벗어나지 않는다.
	var extent := maxf((bounds.size * .5).length(), 1)
	var offset := (point - bounds.get_center()) * (MAP_RADIUS / extent)
	return MINIMAP.get_center() + offset.limit_length(MAP_RADIUS)
