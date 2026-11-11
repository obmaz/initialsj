extends RefCounted
# 생활 건물만 적용하는 마을 구획과 위험 지형의 여유 거리. 광고·식생은 제외한다.
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Library = preload("res://scripts/track/route_library.gd")

static func inhabited(kind: String) -> bool:
	return Props.BUILDING_DIMS.has(kind) or kind in Props.RURAL_KINDS or kind in ["vending_row","bus_shelter"]

static func canyon_spans(road: Node3D) -> Array[Vector2]:
	if road.closed_loop:
		if road.course_id == 3: return preload("res://scripts/track/riviera_profile.gd").CANYONS
		if road.course_id == 4: return [Vector2(1000,road.length-200)]
	elif Library.theme(road.stage,road.route_node) == "canyon":
		return [Vector2(300,1700),Vector2(2390,road.length-280)]
	return []

static func overlaps(road: Node3D, d: float, radius: float, span: Vector2, buffer: float) -> bool:
	if span.y <= span.x: return false
	for shift in ([-road.length,0.0,road.length] if road.closed_loop else [0.0]):
		if d+radius >= span.x+shift-buffer and d-radius <= span.y+shift+buffer: return true
	return false

static func safe_site(road: Node3D, d: float, radius: float) -> bool:
	if overlaps(road,d,radius,road.bridge_span,140): return false
	var tunnel: Vector2 = road.underpass_span() if road.closed_loop else Library.tunnel_span(road.stage,road.route_node)
	# 후지 절개지 경사로까지 포함해 터널 양쪽에 생활 건물을 두지 않는다.
	if overlaps(road,d,radius,tunnel,310 if road.closed_loop and road.course_id == 0 else 140): return false
	for span in canyon_spans(road):
		if overlaps(road,d,radius,span,160): return false
	return true

static func in_cluster(road: Node3D, d: float, radius: float) -> bool:
	if road.closed_loop and road.course_id == 3:
		for span in [Vector2(180,700),Vector2(1530,2000),Vector2(2770,road.length-150)]:
			if d-radius >= span.x and d+radius <= span.y: return true
		return false
	# 도시도 몇 개의 구역으로 나누고 구역 사이에는 최소 280m의 빈 구간을 둔다.
	var local := fposmod(d-160+road.route_node*43+road.stage*31,760)
	return local-radius >= 0 and local+radius <= 480

static func allows(road: Node3D, d: float, radius: float) -> bool:
	return in_cluster(road,d,radius) and safe_site(road,d,radius)
