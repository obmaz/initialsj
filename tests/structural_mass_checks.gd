extends RefCounted
const Props = preload("res://scripts/regional_props_3d.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func ray(race: Node3D, d: float, lane: float) -> Dictionary:
	var p: Vector3 = race.track.point(d,lane)
	return race.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP*.8,1))
func run(tree: SceneTree) -> int:
	for kind in Props.BUILDING_DIMS:
		var mesh: ArrayMesh = Props.model(kind)
		var arrays: Array = mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_INDEX].size()/3 < 3200,"실제 창틀·기단을 보강해도 건물별 모바일 메시 예산을 지켜야 한다: "+kind)
		var fronts := 0
		var sides := 0
		for uv in arrays[Mesh.ARRAY_TEX_UV2]:
			if uv.x < 9.5 or uv.x > 24: continue
			if uv.y > .5: fronts += 1
			else: sides += 1
		check(fronts > 0 and sides > 0,"각 건물은 전용 정면과 별도 측면 이미지 영역을 사용해야 한다: "+kind)
	# 승용차 길이 4.3m에 대한 실제 영업 공간·성목·광고판의 미터 치수를 검사한다.
	var store := Props.model("convenience_store").get_aabb().size
	check(store.x >= 16 and store.z >= 17 and store.y >= 6,"편의점은 승용차 여러 대가 늘어서는 매장·전정 크기를 가져야 한다")
	var station_bounds := Props.model("gas_station").get_aabb()
	for x in [station_bounds.position.x,station_bounds.end.x]:
		for z in [station_bounds.position.z,station_bounds.end.z]:
			check(Vector2(x,z).length() <= Props.radius("gas_station")+.001,"주유소 이격 반경은 비대칭 부지의 네 모서리를 모두 포함해야 한다")
	var station := station_bounds.size
	check(station.x >= 29 and station.z >= 29,"주유소는 급유 차로와 후면 서비스동이 있는 실제 부지 크기여야 한다")
	var apartment := Props.model("apartment").get_aabb().size
	check(apartment.x >= 18 and apartment.y >= 19 and apartment.z >= 16,"아파트는 자동차보다 충분히 큰 동 폭과 다층 높이를 가져야 한다")
	for kind in ["palm","pine","plane_tree","ginkgo"]+Props.Models.TREES:
		var height: float = Props.model(kind).get_aabb().size.y
		check(height >= 14 and height <= 30,"성목은 승용차 높이의 여러 배인 실제 수고를 가져야 한다: "+kind)
	var advert := Props.model("billboard").get_aabb().size
	check(advert.x >= 14 and advert.y >= 15,"도로변 광고판은 자동차 여러 대 길이의 패널과 지주를 가져야 한다")
	var station_arrays: Array = Props.model("gas_station").surface_get_arrays(0)
	var canopy_under := INF
	for i in range(station_arrays[Mesh.ARRAY_VERTEX].size()):
		var vertex: Vector3 = station_arrays[Mesh.ARRAY_VERTEX][i]
		var normal: Vector3 = station_arrays[Mesh.ARRAY_NORMAL][i]
		if absf(vertex.z) < 8 and vertex.y > 5 and normal.y < -.9: canopy_under = minf(canopy_under,vertex.y)
	check(canopy_under >= 5.2 and canopy_under <= 6.5,"주유소 캐노피는 실제 차량 통과 높이를 유지해야 한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",4)
	race.restart()
	var collapse: Node3D = race.track.active.collapse
	for feature in race.track.active.features:
		var overlaps: bool = feature.distance+feature.length*.5 > collapse.span.x and feature.distance-feature.length*.5 < collapse.span.y
		var inner: float = race.track.active.surface_lane(collapse.lanes.x,feature.distance)
		var outer: float = race.track.active.surface_lane(collapse.lanes.y,feature.distance)
		var crosses: bool = feature.lane+feature.width*.5 > inner and feature.lane-feature.width*.5 < outer
		check(not (overlaps and crosses),"붕괴한 도로 위에 부스터·기믹 표시가 떠 있으면 안 된다")
	await tree.physics_frame
	check(race.track.active.has_node("SolidRoadEdges"),"도로 옆면은 실제 두께를 가진 입체 메시여야 한다")
	for d in [424.0,430.0,436.0]:
		check(not ray(race,d,8).is_empty(),"붕괴 전에는 상판 세 조각에 실제 바닥이 있어야 한다")
	for i in range(collapse.PIECES): check(not ray(race,collapse.span.x+(i+.5)*collapse.PIECE_LENGTH,8).is_empty(),"확장 상판의 모든 조각에 최초 실제 바닥이 있어야 한다")
	check(collapse.warning(200).contains("KEEP LEFT"),"붕괴 전에 왼쪽 통과로를 안내해야 한다")
	collapse.advance(.6,300)
	await tree.physics_frame
	check(not ray(race,430,8).is_empty(),"경고 단계에서는 도로가 먼저 사라지면 안 된다")
	for frame in range(180): collapse.advance(1.0/60,300)
	check(collapse.broken and collapse.chunks[0].position.y < collapse.origins[0].y-10,"접근 중에 상판이 눈앞에서 붕괴해야 한다")
	var jump_found := false
	for feature in race.track.active.features:
		if feature.kind == "ramp" and feature.distance < collapse.span.x and feature.distance+feature.length*.5 > collapse.span.x-15: jump_found = true
	check(jump_found,"붕괴 구간 바로 앞에 점프대가 있어야 한다")
	await tree.physics_frame
	for d in [424.0,430.0,436.0]:
		check(ray(race,d,8).is_empty(),"붕괴한 도로에 보이지 않는 충돌 바닥을 남기면 안 된다")
		check(not ray(race,d,-3).is_empty(),"붕괴 뒤에도 왼쪽 차선은 실제로 통과할 수 있어야 한다")
	for i in range(collapse.PIECES): check(ray(race,collapse.span.x+(i+.5)*collapse.PIECE_LENGTH,8).is_empty(),"확장 상판의 모든 조각에서 실제 바닥이 사라져야 한다")
	check(collapse.span.y-collapse.span.x >= 100 and collapse.wreckage.visible,"100m 이상 붕괴와 지속되는 파단 흔적이 있어야 한다")
	collapse.advance(.1,race.track.length+200)
	check(collapse.broken and collapse.wreckage.visible and collapse.floors[0].collision_layer == 0,"한 바퀴 뒤에도 파손과 도로 소실이 남아야 한다")
	race.state = "paused"
	var before: float = collapse.elapsed
	race._physics_process(.25)
	check(collapse.elapsed == before,"일시정지 중에는 붕괴와 낙하 시간을 멈춰야 한다")
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	race.world_race.teleport(0,400,-3)
	var body: CharacterBody3D = race.world_race.player_body
	body.velocity = body.forward_direction()*65
	race.speed = 65
	for frame in range(70): race.step(1.0/60,0,false,false,false)
	check(race.distance > 450 and race.wall_hits == 0 and body.grounded,"왼쪽 통과로는 실제 차체로 충돌·낙하 없이 지나갈 수 있어야 한다")
	race.world_race.teleport(0,430,8)
	for frame in range(45): race.step(1.0/60,0,false,false,false)
	check(body.feet_position().y < race.track.point(430,8).y-3,"사라진 상판 위의 차량은 실제 중력으로 떨어져야 한다")
	race.world_race.safe_distance = 430
	race.world_race.safe_lane = 8
	check(race.world_race.recover_player() and race.lane < 3,"복구는 사라진 도로 대신 남아 있는 바닥을 선택해야 한다")
	race.restart()
	await tree.physics_frame
	check(collapse.elapsed < 0 and not ray(race,430,8).is_empty(),"다시 시작하면 상판과 충돌체를 함께 복원해야 한다")
	# 상대 차량도 위험 구간 전에 합류해 사라진 차선으로 달리지 않는다.
	collapse.advance(3,550)
	race.state = "racing"
	race.world_race.teleport(0,160,-3)
	race.rivals[0].active = true
	race.world_race.teleport(1,140,7)
	var rival_body: CharacterBody3D = race.world_race.bodies[1]
	rival_body.velocity = rival_body.forward_direction()*65
	race.rivals[0].speed = 65
	var crossed := false
	for frame in range(420):
		await tree.physics_frame
		race.step(1.0/60,0,false,false,false)
		var d: float = race.rivals[0].distance
		if d > 420 and d < 440: check(race.rivals[0].lane < 2.5,"상대 차량은 붕괴 구간에서 왼쪽 통과로를 선택해야 한다")
		if d > 445: crossed = true; break
	check(crossed,"상대 차량이 붕괴 다리의 남은 차선으로 계속 진행해야 한다")
	# 실제 차체가 새 점프대를 타고 108m 붕괴 구간을 넘어 착지해야 한다.
	for choice in range(4):
		race.state = "ready"
		race.select_vehicle(choice)
		race.restart()
		race.state = "racing"
		for rival in race.rivals: rival.active = false
		race.world_race.teleport(0,330,7.5)
		body = race.world_race.player_body
		body.velocity = body.forward_direction()*65
		race.speed = 65
		var airborne_over_gap := false
		var landed_beyond := false
		for frame in range(420):
			race.step(1.0/60,0,false,true,false)
			if race.distance > 450 and race.distance < 520 and not body.grounded: airborne_over_gap = true
			if race.distance > 540 and body.grounded: landed_beyond = true; break
		check(airborne_over_gap and landed_beyond and race.wall_hits == 0,"모든 차량은 점프대로 붕괴 구간을 건너 실제 노면에 착지해야 한다: %s / d %.1f / grounded %s / walls %d" % [race.vehicle.id,race.distance,body.grounded,race.wall_hits])
	race.queue_free()
	await tree.process_frame
	print("건물 전용 외벽·기단 / 다리 붕괴·실제 도로 소실·통과·복구: ","PASS" if failures == 0 else "FAIL")
	return failures
