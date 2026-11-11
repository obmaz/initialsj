extends RefCounted
const Variants = preload("res://scripts/environment/facade_variants.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Architecture = preload("res://scripts/environment/urban_architecture.gd")
const Biome = preload("res://scripts/environment/road_biome.gd")
const Resources = preload("res://scripts/rendering/render_resources.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	Resources.acquire_owner()
	var kinds := Architecture.count()
	for style in range(kinds):
		var seen := {}
		for copy in range(Variants.URBAN_COUNT):
			var skin := Variants.city_skin(style + copy * kinds, kinds, 1)
			seen[skin] = true
			for variation in [0.0, .5, 1.0]:
				var payload := Variants.encode_city(skin, variation)
				check(
					floori(payload * Variants.URBAN_COUNT) == skin and payload < 1, "외벽 스킨 번호는 색 변형·부동소수점 경계에서도 유지돼야 한다"
				)
		check(seen.size() == Variants.URBAN_COUNT, "12종 형상 순환이 같은 건물의 스킨까지 반복 고정하면 안 된다")
		var material: ShaderMaterial = Architecture.material(style, "city")
		check(
			(
				material.get_shader_parameter("facade_alternate_a") is Texture2D
				and material.get_shader_parameter("facade_alternate_b") is Texture2D
			),
			"모든 도시 형상에 두 추가 외벽 아틀라스를 연결해야 한다"
		)
	var skins := {}
	for i in range(40):
		var p := Vector3(i * 18, 0, i * 5)
		var skin := Variants.prop_skin(p, "convenience_store")
		check(skin == Variants.prop_skin(p, "convenience_store"), "월드 배치의 외벽은 재시작·프레임마다 바뀌면 안 된다")
		skins[skin] = true
	check(skins.size() == Variants.PROP_COUNT, "같은 소품 형상도 서로 다른 외벽을 선택해야 한다")
	for kind in ["convenience_store", "gas_station", "apartment", "warehouse_shed", "ticket_booth"]:
		var material: ShaderMaterial = Props.material_for(kind)
		check(
			(
				material.get_shader_parameter("building_fronts_alt") is Texture2D
				and material.get_shader_parameter("building_sides_alt") is Texture2D
			),
			"일반 건물의 정면·측면 대체 이미지가 함께 연결돼야 한다: " + kind
		)
	var models := Props.new()
	var placements: Array[Dictionary] = [
		{"kind": "convenience_store", "position": Vector3.ZERO, "skin": 0},
		{"kind": "convenience_store", "position": Vector3(50, 0, 0), "skin": 1}
	]
	models.configure("city", placements)
	tree.root.add_child(models)
	check(
		models.batches.size() == 1 and models.batches[0].multimesh.instance_count == 2,
		"외벽이 다른 같은 건물도 하나의 MultiMesh 배치를 공유해야 한다"
	)
	check(models.batches[0].multimesh.mesh == Props.model("convenience_store"), "스킨 변형이 메시를 복제하거나 형상 크기를 바꾸면 안 된다")
	models.free()
	for region in ["city", "seoul", "ruins", "neon"]:
		var paths := Biome.warm_paths(region)
		check(Variants.URBAN_A in paths and Variants.URBAN_B in paths, "도시 지역 전환 전에 추가 외벽 이미지를 미리 읽어야 한다")
	check(not Props.textures_for("basalt").has("building_fronts_alt"), "외벽을 쓰지 않는 바위가 건물 이미지를 붙잡으면 안 된다")
	if Resources.release_owner():
		Props.clear_cache()
		preload("res://scripts/environment/tour_vegetation.gd").clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
	print("도시 형상별3스킨 / 정면·측면2스킨 / 고정 선택·변형 경계 / 단일 배치·공유 메시 / 미리 읽기: ", "PASS" if failures == 0 else "FAIL")
	return failures
