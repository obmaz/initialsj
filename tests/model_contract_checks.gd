extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Car = preload("res://scripts/vehicles/car.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const SceneSource = preload("res://models/shared/scene_source.gd")
const Architecture = preload("res://scripts/environment/urban_architecture.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in range(mesh.get_surface_count()):
		var data := mesh.surface_get_arrays(surface)
		count += (
			(data[Mesh.ARRAY_INDEX].size() if data[Mesh.ARRAY_INDEX] != null else data[Mesh.ARRAY_VERTEX].size()) / 3
		)
	return count


func visual_triangles(node: Node) -> int:
	var count := triangles(node.mesh) if node is MeshInstance3D else 0
	for child in node.get_children():
		count += visual_triangles(child)
	return count


func metadata(item: Resource) -> bool:
	var before := failures
	var folder: String = "res://models/" + item.category + "/" + item.id + "/"
	check(
		item.contract_version == 2 and RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(item.id) != null,
		"모델 계약 버전·ID: " + folder
	)
	check(
		FileAccess.file_exists(item.source_path) and item.source_path.begins_with(folder),
		"팩 내부의 출처 문서가 필요하다: " + folder
	)
	check(item.scene_path.ends_with(".tscn"), "모델 진입점은 GLB를 조립하는 .tscn이어야 한다: " + folder)
	for path in [item.scene_path, item.material_path]:
		if not path.is_empty():
			check(ResourceLoader.exists(path), "모델 리소스 누락: " + path)
	for path in [item.scene_path, item.material_path]:
		if not path.is_empty():
			check(path.begins_with(folder), "전용 씬·재질은 자기 모델 팩에 둔다: " + folder)
	if item.category == "vehicles":
		for field in ["wheel_radius", "wheel_half_track", "wheel_half_base", "wheel_thickness", "ride_offset"]:
			check(item.parameters.has(field), "차량 제원 누락: " + folder + field)
	if item.category == "buildings":
		for field in ["height_range", "width_range", "depth_range"]:
			var value: Variant = item.parameters.get(field)
			check(
				value is Vector2 and value.is_finite() and value.x > 0 and value.y >= value.x,
				"건물 치수 범위: " + folder + field
			)
	return failures == before


func run(tree: SceneTree, category: String = "", id: String = "") -> int:
	Pool.acquire_owner()
	var checked := 0
	for group in ["props", "vehicles", "buildings", "vegetation"]:
		if not category.is_empty() and category != group:
			continue
		for item in Catalog.all(group):
			if not id.is_empty() and item.id != id:
				continue
			checked += 1
			if not metadata(item):
				continue
			if group == "props":
				if item.parameters.get("scene_only", false):
					var scene := SceneSource.instantiate_static(item.scene_path)
					check(visual_triangles(scene) <= 5000, "조립형 소품은5000삼각형 이하: " + item.id)
					for part in SceneSource.collect_meshes(scene):
						check(part.material_override != null, "조립형 소품의 전용 재질: " + item.id)
						for surface in range(part.mesh.get_surface_count()):
							check(
								part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV] != null,
								"조립형 소품 UV: " + item.id
							)
					scene.free()
					continue
				var mesh: ArrayMesh = Props.model(item.id)
				check(mesh.get_surface_count() == 1 and triangles(mesh) < 3200, "소품은 한 표면·3200삼각형 미만: " + item.id)
				var bounds := mesh.get_aabb()
				check(
					(
						bounds.position.is_finite()
						and bounds.size.is_finite()
						and bounds.size.x > 0
						and bounds.size.y > 0
						and bounds.size.z > 0
					),
					"실제 부피가 있는 유한한 모델: " + item.id
				)
				var data := mesh.surface_get_arrays(0)
				check(
					(
						data[Mesh.ARRAY_NORMAL] != null
						and data[Mesh.ARRAY_NORMAL].size() == data[Mesh.ARRAY_VERTEX].size()
					),
					"모든 소품 정점에 법선이 있어야 한다: " + item.id
				)
			elif group == "vehicles":
				var car := Car.new()
				car.model = item.id
				tree.root.add_child(car)
				check(
					(
						car.wheels.size() == 4
						and car.wheel_radius > 0
						and car.wheel_half_base > 0
						and car.wheel_half_track > 0
					),
					"차량 휠4개와 미터 치수: " + item.id
				)
				check(visual_triangles(car) < 20000, "차량은2만 삼각형 미만: " + item.id)
				check(car.headlight != null and car.headlamp_lenses.size() == 2, "차량은 공통 전조등 연결점을 유지해야 한다: " + item.id)
				car.queue_free()
				await tree.process_frame
			elif group == "vegetation":
				var source: Resource = load(item.scene_path)
				var mesh: Mesh
				if source is PackedScene:
					var scene: Node = source.instantiate()
					mesh = SceneSource.collect_meshes(scene)[0].mesh
					scene.free()
				else:
					mesh = source
				check(mesh.get_surface_count() == 2 and triangles(mesh) <= 4358, "식생의 줄기·잎 표면과 예산: " + item.id)
				check(item.parameters.height > 0 and mesh.get_aabb().size.y > 0, "식생 실척: " + item.id)
			else:
				for dimensions in [Vector3(24, 20, 28), Vector3(42, 120, 48)]:
					var parts: Array = Architecture.parts(item.order, dimensions.x, dimensions.y, dimensions.z)
					check(not parts.is_empty() and parts.size() <= 32, "도시 빌딩의 파츠 예산: " + item.id)
					for part in parts:
						check(
							(
								part.position.is_finite()
								and part.size.is_finite()
								and part.size.x > 0
								and part.size.y > 0
								and part.size.z > 0
							),
							"도시 빌딩의 유효한 파츠: " + item.id
						)
	check(checked > 0, "검사할 모델 ID를 찾지 못했다: " + category + "/" + id)
	for error in Catalog.errors:
		check(false, error)
	if category.is_empty():
		var mesh := SceneSource.prop_mesh("res://tests/fixtures/models/textured_prop.tscn")
		check(
			(
				mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] != null
				and mesh.surface_get_material(0).albedo_texture != null
			),
			"외부 정적 씬의 UV·텍스처를 유지해야 한다"
		)
		var shared := SceneSource.prop_mesh("res://tests/fixtures/models/textured_prop.tscn")
		check(
			mesh == shared and mesh.get_aabb().size.is_equal_approx(Vector3(2, 4, 6)), "GLB는 미터 치수와 같은 메시 자원을 공유해야 한다"
		)

	if Pool.release_owner():
		Props.clear_cache()
		preload("res://scripts/environment/advertisement_library.gd").clear_cache()
	print("모델 팩 자동 등록 / 치수·휠·메시 예산 / 외부 모델 UV·재질 보존: ", "PASS" if failures == 0 else "FAIL", " (", checked, "개)")
	return failures
