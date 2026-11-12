extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	for side in [-1, 0, 1]:
		var road := Section.new(Vector3(0, 6, 0), -PI / 2, 3, 1, side)
		tree.root.add_child(road)
		var landmarks := road.scenery.get_node("TourLandmarks")
		for id in ["sungnyemun_gate", "namsan_tower", "golden_63_tower", "seoul_sky_tower"]:
			check(landmarks.has_node(id), "서울 랜드마크는 모든 진입 형상에 있어야 한다: " + id)
		var gate: Node3D = landmarks.get_node("sungnyemun_gate")
		check(gate.global_position.distance_to(road.to_global(road.point(620))) < .1, "숭례문 통과 공간은 실제 도로 중심에 정렬한다")
		var block: MultiMeshInstance3D = landmarks.get_node("SkywayAbutments")
		check(block.get_meta("collision_transforms").size() > 20, "고가 아래 공간은 연속 교대로 막는다")
		var collision := preload("res://scripts/physics/world_collision.gd").build(road)
		road.add_child(collision)
		await tree.physics_frame
		await tree.physics_frame
		for feature in road.features:
			if feature.kind != "skyway":
				continue
			var start: Vector3 = (
				road.to_global(road.point(feature.distance, feature.lane - signf(feature.lane) * (feature.width + 2)))
				+ Vector3.UP
			)
			var end: Vector3 = road.to_global(road.point(feature.distance, feature.lane)) + Vector3.UP
			var query := PhysicsRayQueryParameters3D.create(start, end, 2)
			check(
				not road.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
				"하부 도로에서 고가 밑으로 들어가는 실제 경로가 차단된다"
			)
		road.free()
		await tree.process_frame
	for side in [-1, 0, 1]:
		var road := Section.new(Vector3(0, 6, 0), -PI / 2, 2, 1, side)
		tree.root.add_child(road)
		check(road.scenery.get_node("TourLandmarks").get_child_count() == 28, "유리 회랑은 기존96m에서320m로 이어진다")
		road.free()
		await tree.process_frame
	print("서울3진입 랜드마크 정렬 / 고가 하부 실제 차단 / 유리 회랑 연장: ", "PASS" if failures == 0 else "FAIL")
	return failures
