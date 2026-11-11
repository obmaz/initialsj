extends SceneTree
# 실제 코스 형상의 GLB 연결·프로필·크기·초기 상태를 독립적으로 검사한다.
const Assets = preload("res://scripts/rendering/world_assets.gd")
const State = preload("res://models/shared/scene_state.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const GeometryMap = preload("res://models/shared/world_geometry_map.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func check_material_variants() -> void:
	var logical: String = GeometryMap.data().references.keys()[0]
	var path := GeometryMap.resolve(logical).get_slice("#", 0)
	var source: Node3D = Pool.shared_world_scenes[path].instantiate()
	var mesh: Mesh = source.get_node("Visual").mesh
	source.free()
	var nodes: Array[Node] = []
	for color in [Color.RED, Color.BLUE, Color.RED]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.set_meta(&"mesh_ref", logical)
		node.set_meta(&"surface_materials", [material, StandardMaterial3D.new()])
		nodes.append(node)
	var context := {"members": nodes, "meshes": {logical: mesh}, "bound": {}, "material_keys": {}}
	Assets.bind_geometry(context, 0, nodes.size())
	check(nodes[0].multimesh.mesh == nodes[2].multimesh.mesh, "별도 인스턴스의 같은 재질도 메시 바인딩을 공유한다")
	check(nodes[0].multimesh.mesh != nodes[1].multimesh.mesh, "다른 식생 색·재질을 공유 바인딩으로 덮어쓰면 안 된다")
	var red: StandardMaterial3D = nodes[0].multimesh.mesh.surface_get_material(0)
	var blue: StandardMaterial3D = nodes[1].multimesh.mesh.surface_get_material(0)
	check(red.albedo_color == Color.RED and blue.albedo_color == Color.BLUE, "공유 형상의 재질 변형을 유지한다")
	var subtle_a := StandardMaterial3D.new()
	var subtle_b := StandardMaterial3D.new()
	subtle_a.albedo_color = Color(.5, 0, 0)
	subtle_b.albedo_color = Color(.50000006, 0, 0)
	check(GeometryMap.material_key([subtle_a]) != GeometryMap.material_key([subtle_b]), "작은 색 차이도 문자열 반올림으로 합치지 않는다")
	for node in nodes:
		node.free()


func run() -> void:
	Pool.acquire_owner()
	var count := 0
	var shared_seen := {}
	var shared_hits := 0
	for name in DirAccess.get_directories_at("res://models/world"):
		var folder := "res://models/world/" + name + "/"
		var resource: Resource = load(folder + "profile.tres")
		var profile: Dictionary = resource.get_meta(&"profile")
		check(absf(profile.curve.get_baked_length() - profile.length) < .05, "GLB 코스 프로필의 길이: " + name)
		var scene: Node3D = load(folder + "model.tscn").instantiate()
		check(scene.get_meta(&"asset_schema") == 1, "코스 조립 계약 버전: " + name)
		Assets.geometry(scene)
		var total := 0
		for node in Assets.nodes(scene):
			State.bind(node)
			if node is MeshInstance3D or node is CPUParticles3D or node is MultiMeshInstance3D:
				var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh
				check(
					mesh is ArrayMesh and node.has_meta(&"mesh_ref"),
					"코스 형상은 GLB의 메시여야 한다: " + name + "/" + str(node.name)
				)
				if mesh == null:
					continue
				var resolved := GeometryMap.resolve(node.get_meta(&"mesh_ref", ""))
				if node is MultiMeshInstance3D and GeometryMap.shared(resolved.get_slice("#", 0)):
					var key := resolved + GeometryMap.material_key(node.get_meta(&"surface_materials", []))
					if shared_seen.has(key):
						check(shared_seen[key] == mesh, "같은 공통 식생·재질은 코스 간에도 실제 메시를 공유해야 한다")
						shared_hits += 1
					else:
						shared_seen[key] = mesh
				var bounds := mesh.get_aabb()
				check(bounds.position.is_finite() and bounds.size.is_finite(), "GLB 경계는 유한해야 한다: " + name)
				total += mesh.get_faces().size() / 3
		check(total > 2000 and scene.road_surface.mesh.get_faces().size() > 3000, "도로와 지형의 실제 삼각형: " + name)
		check(is_equal_approx(scene.length, profile.length), "주행 프로필과 씬의 길이 일치: " + name)
		scene.free()
		count += 1
		await process_frame
	check(count == 48, "서킷5개·투어 진입 변형43개를 모두 검사한다")
	check(shared_hits > 100 and Pool.shared_world_scenes.size() == 7, "공통 식생7종의 코스 간 공유를 검사한다")
	check_material_variants()
	for steps in [0, 3, 16, 64]:
		var road := preload("res://scripts/track/road_section.gd").new(Vector3(0, 6, 0), -PI / 2, 1, 0)
		road.staged = true
		root.add_child(road)
		road.build_some(0)
		var context: Dictionary = road.asset_context
		var temporary: WeakRef = weakref(context.root)
		for step in range(steps):
			road.build_some(0)
		road.free()
		check(temporary.get_ref() == null and context.is_empty(), "단계별 생성 취소가 임시 씬과 메시 참조를 해제해야 한다")
		await process_frame
	var cached: WeakRef = weakref(Pool.shared_world_scenes.values()[0])
	shared_seen.clear()
	Pool.release_owner()
	check(
		cached.get_ref() == null and Pool.shared_world_materials.is_empty() and GeometryMap.manifest.is_empty(),
		"마지막 소유자가 나가면 공통 식생 씬·재질 바인딩·연결표를 해제해야 한다"
	)
	print("GLB 코스48개 / 형상·경계·주행 프로필 / 생성 중단 시 임시 씬 해제: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
