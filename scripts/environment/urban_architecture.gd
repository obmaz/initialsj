extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const Variants = preload("res://scripts/environment/facade_variants.gd")
const FACADE_IMAGES := "res://assets/environment/urban-harbor-facades.png"
const FACADE_EXTRA := "res://assets/environment/urban-truck-elevations.png"
const STRUCTURE_IMAGES := "res://assets/environment/generated-structure-variants.png"


static func count() -> int:
	return Catalog.all("buildings").size()


static func definition(style: int) -> Resource:
	return Catalog.all("buildings")[posmod(style, count())]


static func parts(style: int, width: float, height: float, depth: float) -> Array[Dictionary]:
	var item: Resource = definition(style)
	return load(item.builder_path).build(item, width, height, depth)


# 조립 파츠 하나의 노출 모서리·파라펫. 창 이미지를 가리는 추가 외벽은 만들지 않는다.
static func mass_parts(size: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var edge := clampf(minf(size.x, size.z) * .018, .42, .9)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			out.append({"position": Vector3(x * size.x * .5, 0, z * size.z * .5), "size": Vector3(edge, size.y, edge)})
	for z in [-1.0, 1.0]:
		out.append({"position": Vector3(0, size.y * .5, z * size.z * .5), "size": Vector3(size.x + edge, .65, edge)})
	for x in [-1.0, 1.0]:
		out.append({"position": Vector3(x * size.x * .5, size.y * .5, 0), "size": Vector3(edge, .65, size.z)})
	return out


static func mass_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/painted_steel.gdshader")
	material.set_shader_parameter("material_atlas", RenderResources.fetch(STRUCTURE_IMAGES))
	material.set_shader_parameter("material_tile", Vector2(0, 0))
	material.set_shader_parameter("paint_color", Color("c8c5bb"))
	material.set_shader_parameter("metalness", 0.0)
	material.set_shader_parameter("surface_roughness", .91)
	material.set_shader_parameter("concrete_family", true)
	material.set_shader_parameter("uv_projection", true)
	material.set_shader_parameter("texture_scale", .28)
	return material


# 180m 단위 공간 배치로 묶어 멀리 있는 구조물 장식을 함께 그리지 않는다.
static func add_mass(parent: Node3D, poses: Array[Transform3D]) -> void:
	if poses.is_empty():
		return
	var groups := {}
	for pose in poses:
		var cell := Vector2i(floori(pose.origin.x / 180), floori(pose.origin.z / 180))
		if not groups.has(cell):
			groups[cell] = []
		groups[cell].append(pose)
	var material := mass_material()
	for cell in groups:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = RenderResources.unit_box()
		multi.instance_count = groups[cell].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, groups[cell][i])
		var node := MultiMeshInstance3D.new()
		node.name = "ArchitectureMass_%d_%d" % [cell.x, cell.y]
		node.multimesh = multi
		node.material_override = material
		node.visibility_range_end = 420
		parent.add_child(node)


static func bind_images(material: ShaderMaterial) -> void:
	material.set_shader_parameter("facade_images", RenderResources.fetch(FACADE_IMAGES))
	material.set_shader_parameter("facade_extra", RenderResources.fetch(FACADE_EXTRA))
	material.set_shader_parameter("facade_alternate_a", RenderResources.fetch(Variants.URBAN_A))
	material.set_shader_parameter("facade_alternate_b", RenderResources.fetch(Variants.URBAN_B))


static func material(style: int, theme: String) -> Material:
	var definition: Resource = definition(style)
	if not definition.material_path.is_empty():
		return load(definition.material_path)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/building_facade.gdshader")
	bind_images(material)
	material.set_shader_parameter("ruined", theme == "ruins")
	material.set_shader_parameter("facade_style", definition.parameters.facade_index)
	material.set_shader_parameter("night_city", theme == "neon")
	material.set_shader_parameter("regional_style", 1 if theme == "seoul" else (2 if theme == "neon" else 0))
	return material
