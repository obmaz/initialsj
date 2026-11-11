extends RefCounted


# 외부 제작 정적 씬을 공통 렌더 계약으로 가져온다. 주행 스크립트·물리·광원은 씬에 넣지 않는다.
static func allowed(packed: PackedScene) -> bool:
	var state := packed.get_state()
	for i in range(state.get_node_count()):
		var instance: PackedScene = state.get_node_instance(i)
		if instance != null and not allowed(instance):
			return false
		for p in range(state.get_node_property_count(i)):
			if state.get_node_property_name(i, p) == &"script" and state.get_node_property_value(i, p) != null:
				return false
	return true


static func instantiate_static(path: String) -> Node3D:
	var packed: PackedScene = load(path)
	assert(allowed(packed), "모델 씬에는 실행 스크립트를 넣지 않는다: " + path)
	var root := packed.instantiate() as Node3D
	assert(root != null, "모델 루트는 Node3D여야 한다: " + path)
	check_nodes(root)
	return root


static func check_nodes(node: Node) -> void:
	assert(node.get_class() in ["Node3D", "MeshInstance3D", "Marker3D"], "정적 모델에 허용되지 않는 노드: " + node.get_class())
	for child in node.get_children():
		check_nodes(child)


static func collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(collect_meshes(child))
	return result


static func prop_mesh(path: String) -> ArrayMesh:
	var root := instantiate_static(path)
	var meshes := collect_meshes(root)
	assert(meshes.size() == 1, "일반 오브젝트 씬은 메시 노드 하나로 내보낸다: " + path)
	var node: MeshInstance3D = meshes[0]
	var transform := node.transform
	var parent: Node = node.get_parent()
	while parent is Node3D:
		transform = parent.transform * transform
		parent = parent.get_parent()
	assert(transform.is_equal_approx(Transform3D.IDENTITY), "GLB 내보내기 전에 축·원점·미터 스케일을 적용한다")
	assert(node.mesh is ArrayMesh and node.mesh.get_surface_count() == 1, "소품 GLB는 단일 표면이다")
	var result := node.mesh as ArrayMesh
	root.free()
	return result
