extends SceneTree
# 실제 코스 형상의 GLB 연결·프로필·크기·초기 상태를 독립적으로 검사한다.
const Assets = preload("res://scripts/rendering/world_assets.gd")
const State = preload("res://models/shared/scene_state.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	Pool.acquire_owner()
	var count := 0
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
				var bounds := mesh.get_aabb()
				check(bounds.position.is_finite() and bounds.size.is_finite(), "GLB 경계는 유한해야 한다: " + name)
				total += mesh.get_faces().size() / 3
		check(total > 2000 and scene.road_surface.mesh.get_faces().size() > 3000, "도로와 지형의 실제 삼각형: " + name)
		check(is_equal_approx(scene.length, profile.length), "주행 프로필과 씬의 길이 일치: " + name)
		scene.free()
		count += 1
		await process_frame
	check(count == 48, "서킷5개·투어 진입 변형43개를 모두 검사한다")
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
	Pool.release_owner()
	print("GLB 코스48개 / 형상·경계·주행 프로필 / 생성 중단 시 임시 씬 해제: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
