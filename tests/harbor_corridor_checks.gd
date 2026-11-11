extends RefCounted
const Corridor = preload("res://scripts/track/harbor_corridor.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track", 2)
	var road: Node3D = race.track.active
	await tree.physics_frame
	check(
		is_equal_approx(road.half_width(1500) * 2, 8.4) and road.half_width(1300) > 7,
		"항만 직선은 넓은 도로에서8.4m 두 차선 작업 통로로 좁혀져야 한다"
	)
	var cargo: ArrayMesh = road.scenery.cargo_mesh(0)
	var arrays := cargo.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var cross := (vertices[indices[i + 1]] - vertices[a]).cross(vertices[indices[i + 2]] - vertices[a])
		check(cross.dot(normals[a]) < 0, "컨테이너의 모든 철판은 바깥 법선과 시계 방향 앞면이 일치해야 한다")
	var previous: float = road.half_width(Corridor.SPAN.x)
	for d in range(int(Corridor.SPAN.x), int(Corridor.SPAN.y) + 1, 5):
		var half: float = road.half_width(d)
		check(absf(half - previous) / 5 < .065, "항만 통로의 폭은 갑자기 꺾이지 않고 완만하게 바뀐다")
		previous = half
		if d > Corridor.CORE.x and d < Corridor.CORE.y:
			check(absf(road.curvature(d)) < .002, "두 차선 컨테이너 사잇길은 직선이어야 한다")
		var at: Vector3 = road.point(d)
		var hit := tree.root.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP, 1)
		)
		check(not hit.is_empty(), "비포장 통로도 실제 주행 노면이 있어야 한다")
	for feature in road.features:
		check(
			(
				feature.distance + feature.length * .5 < Corridor.SPAN.x
				or feature.distance - feature.length * .5 > Corridor.SPAN.y
			),
			"비포장 작업 통로에는 레이싱 패드·점프대를 놓지 않는다"
		)
	var count := 0
	for node in road.scenery.get_children():
		if not str(node.name).begins_with("ContainerCorridor_"):
			continue
		count += node.multimesh.instance_count
		check(node.material_override.get_shader_parameter("skins") is Texture2D, "컨테이너 측면·문·지붕은 생성형 이미지 재질을 사용한다")
	check(count >= 140, "양쪽을2~3단으로 쌓은 충분한 양의 컨테이너가 항만 통로를 둘러싸야 한다")
	check(
		road.road_surface.material_override.get_shader_parameter("harbor_corridor") == true,
		"작업 통로 노면은 전용 비포장 질감으로 바뀌어야 한다"
	)
	race.queue_free()
	await tree.process_frame
	print("항만 컨테이너 통로 / 두 차선 직선 / 완만한 축소 / 비포장·실제 노면 / 생성형 재질: ", "PASS" if failures == 0 else "FAIL")
	return failures
