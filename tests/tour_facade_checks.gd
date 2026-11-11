extends RefCounted
const Section = preload("res://scripts/track/road_section.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var pool = preload("res://scripts/rendering/render_resources.gd")
	pool.acquire_owner()
	var regions := 0
	var textured_kinds := {}
	for stage in range(5):
		for route in range(stage + 1):
			var road := Section.new(Vector3(0, 6, 0), -PI / 2, stage, route)
			road.staged = true
			tree.root.add_child(road)
			var slices := 0
			while road.build_pending():
				road.build_some(0)
				slices += 1
			check(slices > 50, "투어 지역은 지형·풍경을 여러 단계로 나누어 준비해야 한다")
			var scenery: Node3D = road.scenery
			for kind in scenery.roadside_art.models.kinds:
				if not Props.Models.definition(kind).tags.has("building"):
					continue
				textured_kinds[kind] = true
				var material: Material = Props.material_for(kind)
				if not Props.Models.definition(kind).material_path.is_empty():
					check(
						material.get_shader_parameter("facades") is Texture2D,
						"전용 GLB 건물의 외벽 이미지가 실제 재질에 연결돼야 한다: " + kind
					)
					continue
				check(
					(
						material.get_shader_parameter("building_fronts") is Texture2D
						and material.get_shader_parameter("building_sides") is Texture2D
						and material.get_shader_parameter("building_fronts_alt") is Texture2D
						and material.get_shader_parameter("building_sides_alt") is Texture2D
					),
					"투어의 실제 배치 건물은 정면·측면 이미지를 함께 사용해야 한다: " + kind
				)
			if scenery.theme in ["city", "seoul", "ruins", "neon"]:
				var buildings := 0
				for batch in scenery.batches:
					var material: Material = batch.material_override
					if (
						material is ShaderMaterial
						and material.shader.resource_path == "res://shaders/building_facade.gdshader"
					):
						buildings += 1
						check(
							(
								material.get_shader_parameter("facade_images") is Texture2D
								and material.get_shader_parameter("facade_extra") is Texture2D
								and material.get_shader_parameter("facade_alternate_a") is Texture2D
								and material.get_shader_parameter("facade_alternate_b") is Texture2D
							),
							"도시·폐허 빌딩의 실제 렌더 재질에 생성형 외벽을 연결한다"
						)
				check(buildings >= 12, "도시·폐허의 모든 빌딩 유형은 이미지 외벽을 사용해야 한다")
			if scenery.theme == "seoul":
				var deck: MultiMeshInstance3D = scenery.get_node("SeoulObservationDeck")
				check(
					(
						deck.material_override.get_shader_parameter("facade_style") == 3
						and deck.material_override.get_shader_parameter("facade_images") is Texture2D
					),
					"서울 전망대의 원형 전망실도 전용 유리 외벽을 사용한다"
				)
			if scenery.theme == "canyon":
				var meshes: Array = scenery.landmarks.get_children().filter(
					func(node):
						return (
							node is MeshInstance3D
							and node.material_override is ShaderMaterial
							and node.material_override.shader.resource_path == "res://shaders/sandstone.gdshader"
						)
				)
				check(
					meshes.size() == 2 and meshes[0].mesh.get_faces().size() > 10000,
					"분할 생성 후에도 두 협곡의 완전한 절벽 메시가 남아야 한다"
				)
			regions += 1
			road.queue_free()
			await tree.process_frame
	check(regions == 15 and textured_kinds.size() >= 6, "투어15지역에서 실제 사용하는 여러 종류의 건물을 검사해야 한다")
	if pool.release_owner():
		Props.clear_cache()
		preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
	print("투어15지역 단계 생성 / 배치 건물 정면·측면 이미지 / 폐허·전망대 외벽 / 협곡 메시 보존: ", "PASS" if failures == 0 else "FAIL")
	return failures
