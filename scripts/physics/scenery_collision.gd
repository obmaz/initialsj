extends RefCounted
# 정적 풍경의 충돌 계약. 나무는 줄기만, 바위는 저비용 형상, 건물은 개구부를 보존한다.
const GeometryMap = preload("res://models/shared/world_geometry_map.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const TERRAIN := ["lakeside_terrain", "grass_ground", "biome_ground", "riviera_ground"]
const FACADES := ["prop_facade", "building_facade", "speedway_facade", "sandstone", "basalt"]
const DECORATIONS := [
	"bush", "grass", "vine", "flower", "moss", "bend_arrow", "digital_chevron", "distant_lightning", "water", "splash"
]


static func kind(node: Node) -> String:
	if not (node is MeshInstance3D or node is MultiMeshInstance3D):
		return ""
	if node.get_meta("world_ground", false) or node.name in ["RoadBase", "DirtShoulders", "TexturedAsphalt"]:
		return "ground"
	if node.get_meta("world_barrier", false):
		return "barrier"
	var material: Material = node.material_override
	var shader: String = material.shader.resource_path.get_file().get_basename() if material is ShaderMaterial else ""
	if shader in TERRAIN:
		return "ground"
	var ref := GeometryMap.resolve(node.get_meta("mesh_ref", ""))
	if ref.contains("/vegetation/") or ref.contains("/world_vegetation/"):
		return "trunk"
	for decoration in DECORATIONS:
		if ref.contains(decoration):
			return ""
	if ref.contains("/models/props/"):
		if ref.contains("rock"):
			return "rock"
		return "solid"
	if ref.contains("/models/buildings/") or shader in FACADES:
		return "solid"
	return ""


static func transforms(node: Node3D, section: Node3D) -> Array[Transform3D]:
	var frames: Array[Transform3D] = []
	var relative: Transform3D = section.global_transform.affine_inverse() * node.global_transform
	if node is MeshInstance3D:
		frames.append(relative)
	else:
		# 개별 변환 조회는 헤드리스에서 단위행렬을 반환한다. 저장된 버퍼는 CPU 값이다.
		var authored: Array = node.get_meta("collision_transforms", [])
		if not authored.is_empty():
			for instance: Transform3D in authored:
				frames.append(relative * instance)
		else:
			var multi: MultiMesh = node.multimesh
			var buffer := multi.buffer
			var stride := 12 + (4 if multi.use_colors else 0) + (4 if multi.use_custom_data else 0)
			assert(buffer.size() == multi.instance_count * stride, "MultiMesh 저장 배치가 필요합니다")
			for i in range(multi.instance_count):
				var offset := i * stride
				var basis := Basis(
					Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
					Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
					Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])
				)
				var origin := Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])
				frames.append(relative * Transform3D(basis, origin))
	return frames


static func mesh_for(node: Node3D) -> Mesh:
	return node.mesh if node is MeshInstance3D else node.multimesh.mesh


static func faces(mesh: Mesh, type: String) -> PackedVector3Array:
	if type not in ["rock", "trunk"]:
		return mesh.get_faces()
	var box := mesh.get_aabb()
	if type == "trunk":
		var width := clampf(box.size.y * .045, .22, .7)
		box = AABB(Vector3(-width * .5, box.position.y, -width * .5), Vector3(width, box.size.y * .55, width))
	return Transform3D(Basis.IDENTITY.scaled(box.size), box.get_center()) * Pool.unit_box().get_faces()


static func collect(
	node: Node, section: Node3D, ground: PackedVector3Array, walls: PackedVector3Array, solids: PackedVector3Array
) -> void:
	# 독자적인 동적 충돌체(붕괴·낙석·교통)는 고정 캐시에 중복해서 굳히지 않는다.
	if node is CollisionObject3D or node.get_meta("parked_car", false) or node.get_meta("parked_truck", false):
		return
	var type := "ground" if node == section.road_surface else kind(node)
	if not type.is_empty():
		var mesh := mesh_for(node)
		if mesh != null:
			var geometry := faces(mesh, type)
			for frame in transforms(node, section):
				if type == "ground":
					ground.append_array(frame * geometry)
				elif type == "barrier":
					walls.append_array(frame * geometry)
				else:
					# 코스 밖에서 복구 판정까지 닿을 수 있는 풍경만 물리에 보낸다.
					var bounds := frame * mesh.get_aabb()
					var center: Vector3 = section.global_transform * bounds.get_center()
					var nearest: Vector3 = section.curve.get_closest_point(center)
					var radius := Vector2(bounds.size.x, bounds.size.z).length() * .5
					if Vector2(center.x - nearest.x, center.z - nearest.z).length() <= 80 + radius:
						solids.append_array(frame * geometry)
	for child in node.get_children():
		collect(child, section, ground, walls, solids)
