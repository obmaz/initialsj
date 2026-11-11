extends RefCounted
# 작은 효과·표면도 GLB에 저장하고 마지막 게임 씬이 끝날 때 참조를 놓는다.
static var meshes: Dictionary = {}


static func mesh(id: String) -> ArrayMesh:
	if not meshes.has(id):
		var scene: Node3D = load("res://models/shared/render_primitives/model.tscn").instantiate()
		for node in preload("res://models/shared/scene_source.gd").collect_meshes(scene):
			meshes[str(node.name)] = node.mesh
		scene.free()
	assert(meshes.has(id), "GLB 기본 형상 누락: " + id)
	return meshes[id]


static func quad(size: Vector2) -> ArrayMesh:
	return mesh("quad_%d_%d" % [roundi(size.x * 100000), roundi(size.y * 100000)])


static func clear() -> void:
	meshes.clear()
