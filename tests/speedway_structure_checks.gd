extends RefCounted
const Course = preload("res://scripts/track/speedway_course.gd")
const Field = preload("res://scripts/environment/speedway_infield.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func faces_of(node: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	if node is MeshInstance3D:
		faces.append_array(node.global_transform * node.mesh.get_faces())
	for child in node.get_children():
		if child is Node3D:
			faces.append_array(faces_of(child))
	return faces


func mesh_height(faces: PackedVector3Array, at: Vector2) -> float:
	var highest := -INF
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var offset := at - Vector2(a.x, a.z)
		var det := ab.cross(ac)
		if absf(det) < .00001:
			continue
		var u := offset.cross(ac) / det
		var v := ab.cross(offset) / det
		if u >= -.00001 and v >= -.00001 and u + v <= 1.00001:
			highest = maxf(highest, a.y + (b.y - a.y) * u + (c.y - a.y) * v)
	return NAN if highest == -INF else highest


func check_advertisement_clearance(road: Node3D, ads: Array) -> void:
	# 배치 기준 도로뿐 아니라 인필드의 인접 구간까지 실제 모델 외곽과 비교한다.
	var samples: Array[Vector3] = []
	var count := ceili(road.length / 3)
	for i in range(count):
		var d: float = road.length * i / count
		var p: Vector3 = road.point(d)
		samples.append(Vector3(p.x, p.z, road.half_width(d)))
	var bounds := Props.model("billboard").get_aabb()
	for ad in ads:
		var frame := Transform3D(Basis(Vector3.UP, ad.yaw), ad.position)
		var clearance := INF
		for x in [bounds.position.x, 0.0, bounds.end.x]:
			for z in [bounds.position.z, 0.0, bounds.end.z]:
				var p := frame * Vector3(x, 0, z)
				for sample in samples:
					clearance = minf(clearance, Vector2(p.x - sample.x, p.z - sample.y).length() - sample.z)
		check(clearance >= 2, "광고판 전체 외곽은 인접 인필드를 포함한 모든 도로에서2m 이상 떨어진다")


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 1)
	var scenery: Node3D = race.track.scenery
	var outer := faces_of(scenery.get_node("SpeedwayOuterGround"))
	var inner := faces_of(scenery.get_node("SpeedwayInnerGround"))
	for side in [-1.0, 1.0]:
		var faces := inner if side < 0 else outer
		for index in [1, 4, 8, 14, 19, 23]:
			var d: float = Course.offset(race.track.active, index) + 5
			var edge: float = race.track.half_width(d) + race.track.active.rail_setback(d, side) + .65
			for extra in [2.0, 9.0]:
				var p: Vector3 = race.track.point(d, side * (edge + extra))
				var actual := mesh_height(faces, Vector2(p.x, p.z))
				check(
					not is_nan(actual) and absf(actual - scenery.ground_height(d, side * (edge + extra))) < .12,
					"경기장 부지는 실제 국소 지형 띠와 같은 높이에 놓인다"
				)
	var grass := faces_of(scenery.get_node("SpeedwayInfield"))
	var water := faces_of(scenery.get_node("InfieldLake"))
	check(is_nan(mesh_height(grass, Field.CENTER)), "호수 중앙을 잔디 평면으로 덮으면 안 된다")
	check(absf(mesh_height(water, Field.CENTER) - Field.WATER_HEIGHT) < .01, "길쭉한 호수에는 실제 연속 수면이 있어야 한다")
	var water_arrays = scenery.get_node("InfieldLake").mesh.surface_get_arrays(0)
	check(water_arrays[Mesh.ARRAY_NORMAL][0].y > .9, "호수는 위에서 보이는 올바른 면 방향을 사용한다")
	check(
		scenery.grandstand_anchors.size() == 18 and scenery.has_node("GrandstandFoundations"),
		"대형 관중석18개는 지면까지 이어지는 기초를 공유한다"
	)
	var model := Props.model("stadium_grandstand")
	check(model.get_aabb().size.y > 50 and model.get_aabb().size.x >= 74, "관중석은 자동차와 같은 미터 단위로 실제50m 이상 높이를 갖는다")
	var data = model.surface_get_arrays(0)
	var print_count := 0
	for i in range(data[Mesh.ARRAY_VERTEX].size()):
		if data[Mesh.ARRAY_TEX_UV2][i].x > .5:
			print_count += 1
			check(
				data[Mesh.ARRAY_NORMAL][i].y > .9 or data[Mesh.ARRAY_NORMAL][i].z > .9,
				"관중 전용 UV는 좌석 위·정면에 붙어 낮은 시점에서도 보인다"
			)
	check(print_count > 300, "관중석 계단에는 생성형 관중 전용 표면을 포함한다")
	for frame: Transform3D in scenery.grandstand_anchors:
		for x in [-36.0, 36.0]:
			var p := frame * Vector3(x, 0, 0)
			var actual := mesh_height(outer, Vector2(p.x, p.z))
			check(is_nan(actual) or frame.origin.y + .1 >= actual, "관중석 앞열은 도로 제방에 묻히지 않는다")
	check(
		scenery.ad_regions.size() == 2 and scenery.ad_regions[1].x - scenery.ad_regions[0].y > 800,
		"대형 광고열은 떨어진 두 구역으로 나눈다"
	)
	var ads: Array = scenery.get_node("InfieldAdvertisements").placements
	check_advertisement_clearance(race.track, ads)
	for zone in range(2):
		var count := 0
		for ad in ads:
			if ad.distance >= scenery.ad_regions[zone].x - .1 and ad.distance <= scenery.ad_regions[zone].y + .1:
				count += 1
			check(ad.print_fill >= .5, "트랙2 인쇄면은 역광에서도 밝기를 확보한다")
		check(count == 21, "각 광고 구역은21개씩 유지한다")
	check(scenery.wall_ads.size() >= 36, "콘크리트 벽 중간에도 전용 낮은 광고를 배치한다")
	var designs := {}
	for ad in scenery.wall_ads:
		designs[ad.design] = true
		check(ad.height <= scenery.WALL_HEIGHT - .3 and ad.width / ad.height > 9, "벽 광고는 콘크리트 높이 안에 들어가는 전용 가로 규격이다")
	check(designs.size() == 6, "벽 전용 생성형 광고6종을 모두 사용한다")
	for node in scenery.get_node("WallAdvertisements").get_children():
		var ad_data = node.mesh.surface_get_arrays(0)
		var normal: Vector3 = node.global_basis * ad_data[Mesh.ARRAY_NORMAL][0]
		var view_right := Vector3.UP.cross(normal).normalized()
		var edge: Vector3 = node.global_basis * (ad_data[Mesh.ARRAY_VERTEX][1] - ad_data[Mesh.ARRAY_VERTEX][0])
		var du: float = ad_data[Mesh.ARRAY_TEX_UV][1].x - ad_data[Mesh.ARRAY_TEX_UV][0].x
		check(edge.dot(view_right) * du > 0, "도로에서 보는 벽 광고의 글자가 좌우로 뒤집히면 안 된다")

	await tree.physics_frame
	var space := tree.root.get_world_3d().direct_space_state
	for d in [120.0, 1300.0, 4000.0]:
		var side: Vector3 = (race.track.point(d, 1) - race.track.point(d, -1)).normalized()
		side.y = 0
		for height in [1.3, 4.0]:
			var start: Vector3 = race.track.point(d, race.track.half_width(d) - 1) + Vector3.UP * height
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + side * 3, 2))
			check(not hit.is_empty(), "오른쪽 콘크리트와 상단 철망에 실제 충돌면을 둔다")
	var curb: MeshInstance3D = race.track.active.get_node("CurvedCurbs")
	for p in curb.mesh.get_faces():
		var d: float = race.track.active.curve.get_closest_offset(p)
		var center: Vector3 = race.track.point(d)
		var right: Vector3 = (race.track.point(d, 1) - race.track.point(d, -1)).normalized()
		check((p - center).dot(right) < 0, "오른쪽 벽 앞에는 빨강·하양 연석을 만들지 않는다")
	race.queue_free()
	await tree.process_frame
	print("인필드 국소 지형 / 열린 호수 / 대형 관중석·기초 / 광고21+21 / 전용 벽 광고·콘크리트·철망: ", "PASS" if failures == 0 else "FAIL")
	return failures
