extends RefCounted
# 복구할 때만 실제 충돌체를 검사한다. 저장 좌표는 후보일 뿐 안전한 노면을 보장하지 않는다.
const WorldCar = preload("res://scripts/physics/world_car.gd")
const SEARCH_STEP := 8.0
const SURFACE_MARGIN := .2
const RUNOUT := 6.0


static func stable_hit(space: PhysicsDirectSpaceState3D, at: Vector3, up: Vector3, reach: float) -> Dictionary:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + up * reach, at - up, 1))
	if hit.is_empty() or hit.normal.y < .4:
		return {}
	# 아직 무너지지 않았어도 곧 사라질 상판에는 복구하지 않는다.
	if hit.collider.get_meta("recovery_unsafe", false):
		return {}
	return hit


static func candidate(race: Node3D, body: CharacterBody3D, d: float, lane: float) -> Dictionary:
	var road: Node3D = race.track
	var direction: Vector3 = road.point(d + 2, lane) - road.point(d - 2, lane)
	var right: Vector3 = (road.point(d, 1) - road.point(d, -1)).normalized()
	var up := right.cross(direction.normalized()).normalized()
	var space := body.get_world_3d().direct_space_state
	var ground := stable_hit(space, road.point(d, lane), up, 2)
	if ground.is_empty():
		return {}
	up = ground.normal
	var forward := direction.slide(up).normalized()
	var basis := Basis.looking_at(forward, up)
	var feet: Vector3 = ground.position + up * .04
	var half_size: Vector3 = body.contact_shape.shape.size * .5
	# 중심·차축·네 모서리까지 지지되어야 한다. 중심만 남은 가장자리·좁은 틈은 거부한다.
	for x in [-half_size.x - SURFACE_MARGIN, 0.0, half_size.x + SURFACE_MARGIN]:
		for z in [-half_size.z - SURFACE_MARGIN, 0.0, half_size.z + SURFACE_MARGIN]:
			var at: Vector3 = feet + basis * Vector3(x, 0, z)
			var support := stable_hit(space, at, up, .6)
			if support.is_empty() or absf((support.position - feet).dot(up)) > .3:
				return {}
	# 복구 직후 도로 끝으로 떨어지지 않도록 앞쪽에도 차량 폭의 연속 노면을 남긴다.
	for ahead in [3.0, RUNOUT]:
		var next: Vector3 = road.point(d + ahead, lane)
		for side in [-half_size.x, 0.0, half_size.x]:
			if stable_hit(space, next + basis.x * side, up, 2).is_empty():
				return {}
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.contact_shape.shape
	query.transform = Transform3D(basis, feet + up * WorldCar.SUPPORT_HEIGHT)
	query.margin = .25
	query.collision_mask = 6
	query.exclude = [body.get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		return {}
	return {"distance": d, "lane": lane, "feet": feet, "forward": forward, "up": up}


static func find(race: Node3D, body: CharacterBody3D, anchor_distance: float, anchor_lane: float) -> Dictionary:
	var road: Node3D = race.track
	var start := maxf(3, anchor_distance)
	if not road.active.closed_loop:
		start = minf(start, road.length - RUNOUT - 3)
	# 긴 붕괴·낙석 구간도 지나 뒤쪽 도로를 찾는다. 폐회로는 같은 구간을 두 번 검색하지 않는다.
	var limit := minf(road.length, start - 3)
	for step in range(ceili(limit / SEARCH_STEP) + 1):
		var d := start - minf(step * SEARCH_STEP, limit)
		var edge: float = road.half_width(d) - body.contact_shape.shape.size.x * .5 - .45
		for lane in [clampf(anchor_lane, -edge, edge), 0.0, -edge * .45, edge * .45, -edge * .75, edge * .75]:
			var site := candidate(race, body, d, lane)
			if not site.is_empty():
				return site
	return {}
