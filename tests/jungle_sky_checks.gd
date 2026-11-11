extends RefCounted
var failures := 0


func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var library = preload("res://scripts/track/route_library.gd")
	var metadata = preload("res://scripts/environment/tour_region_metadata.gd")
	check(library.theme(1, 0) == "jungle" and not metadata.REGIONS.has("desert"), "사막 경로를 정글로 교체")
	check(metadata.resolve("pyramid").weather == "clear", "피라미드 모래 날림 제거")
	var road = preload("res://scripts/track/road_section.gd").new(Vector3(0, 6, 0), -PI / 2, 1, 0)
	tree.root.add_child(road)
	check(
		road.scenery.theme == "jungle" and road.scenery.get_node("TourNativeVegetation").tree_count > 450,
		"정글 구릉·입체 식생 배치"
	)
	var trees: Node = road.scenery.get_node("TourNativeVegetation")
	check(trees.bank_counts[-1] > 200 and trees.bank_counts[1] > 200, "정글 숲은 양옆을 모두 촘촘하게 채운다")
	var growth: Node = road.scenery.get_node("JungleOvergrowth")
	check(growth.vine_count > 150 and growth.roof_sections >= 6, "정글에는 덩굴과 지면 위로 이어지는 실제 터널 덮개가 있어야 한다")
	check(
		growth.hanging_clearance > 5.5 and growth.has_node("JungleEntrance") and growth.has_node("JungleExit"),
		"늘어진 덩굴은 차량 머리 위 여유를 남기고 양쪽 포털을 감싼다"
	)
	var span: Vector2 = library.tunnel_span(1, 0)
	check(
		(
			road.jungle_cut_depth((span.x + span.y) * .5) > 29
			and road.point(span.x - 120).y > road.point(span.x + 100).y + 10
		),
		"정글 터널은 실제로 아래로 내려가는 절개 도로여야 한다"
	)
	road.queue_free()
	await tree.process_frame
	var staged = preload("res://scripts/track/road_section.gd").new(Vector3(0, 6, 0), -PI / 2, 1, 0)
	staged.staged = true
	tree.root.add_child(staged)
	var maximum_trees := 0
	var steps := 0
	while staged.build_pending() and steps < 1500:
		var before := 0
		if staged.scenery != null and staged.scenery.has_node("TourNativeVegetation"):
			before = staged.scenery.get_node("TourNativeVegetation").tree_count
		staged.build_some(0)
		if staged.scenery != null and staged.scenery.has_node("TourNativeVegetation"):
			maximum_trees = maxi(maximum_trees, staged.scenery.get_node("TourNativeVegetation").tree_count - before)
		steps += 1
	check(not staged.build_pending() and maximum_trees <= 72, "정글 식생 계획은 한 단계에 최대72그루까지만 처리한다")
	trees = staged.scenery.get_node("TourNativeVegetation")
	check(
		trees.planning_slices > 10 and trees.batch_slices > 20 and trees.groups.is_empty(),
		"식생 배치를 여러 프레임으로 나누고 완료한 임시 변환 목록을 해제한다"
	)
	staged.queue_free()
	await tree.process_frame
	var race = preload("res://scripts/race/race.gd").new()
	tree.root.add_child(race)
	await tree.process_frame
	race.warming_world = true
	race.sync_world_rendering()
	var sky: ShaderMaterial = race.atmosphere.sky.sky_material
	check(
		(
			sky != null
			and sky.get_shader_parameter("cloud_panorama") != null
			and not sky.get_shader_parameter("goal_enabled")
		),
		"첫 투어 프레임부터 구름 하늘"
	)
	race.queue_free()
	await tree.process_frame
	print("정글 교체 / 피라미드 맑음 / 첫 프레임 구름 하늘: ", "PASS" if failures == 0 else "FAIL")
	return failures
