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
		for placement in [["golden_63_tower", 2280.0, 160.0], ["seoul_sky_tower", 3440.0, 330.0]]:
			var landmark: Node3D = landmarks.get_node(placement[0])
			check(
				landmark.global_position.distance_to(road.to_global(road.point(placement[1], placement[2]))) < .1,
				"서울의 큰 타워는 모든 진입 형상에서 후반·종료 가까이에 배치한다"
			)
		var gate_mesh: MeshInstance3D = gate.get_node("Model/Model/Visual")
		var gate_arrays := gate_mesh.mesh.surface_get_arrays(0)
		check(
			(
				gate_arrays[Mesh.ARRAY_TEX_UV].size() == gate_arrays[Mesh.ARRAY_VERTEX].size()
				and gate_arrays[Mesh.ARRAY_TEX_UV2].size() == gate_arrays[Mesh.ARRAY_VERTEX].size()
			),
			"숭례문은 석재·기와·단청 전용 반복 UV와 아틀라스 구역을 가진다"
		)
		check(
			gate_mesh.get_active_material(0).get_shader_parameter("heritage_atlas") is Texture2D,
			"숭례문의 입체 형상에 생성형 전용 재질을 실제 연결한다"
		)
		var block: MultiMeshInstance3D = landmarks.get_node("SkywayAbutments")
		check(block.get_meta("collision_transforms").size() > 20, "고가 아래 공간은 연속 교대로 막는다")
		var collision := preload("res://scripts/physics/world_collision.gd").build(road)
		road.add_child(collision)
		var cars := 0
		var trucks := 0
		for child in road.get_children():
			if not child is CharacterBody3D:
				continue
			if child.get_meta("parked_car", false):
				cars += 1
				if child.name.begins_with("PassengerTrafficBody"):
					check(
						child.contact_shape.shape.size.z <= 4.5 and child.feature_record.kind == "car",
						"새 승용차의 실제 충돌 길이와 이동 경고는 승용차 규격을 따른다"
					)
			if child.get_meta("parked_truck", false):
				trucks += 1
		check(cars == 8 and trucks == 2, "서울은 전체 교통 차체 수를 늘리지 않고 승용차8대·트럭2대로 구성한다")
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
