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
	var road = preload("res://scripts/track/road_section.gd").new()
	road.stage = 1
	tree.root.add_child(road)
	check(
		road.scenery.theme == "jungle" and road.scenery.get_node("TourNativeVegetation").tree_count > 450,
		"정글 구릉·입체 식생 배치"
	)
	road.queue_free()
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
