extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const Geometry = preload("res://models/shared/prop_geometry.gd")
const SceneSource = preload("res://models/shared/scene_source.gd")
static var TREES: Array[String] = ids_with_tag("imported_tree")
static var PINES: Array[String] = ids_with_tag("lake_pine")
static var OAKS: Array[String] = ids_with_tag("lake_oak")
static var WILLOWS: Array[String] = ids_with_tag("lake_willow")
static var BUSHES: Array[String] = ids_with_tag("lake_bush")
static var ROCKS: Array[String] = ids_with_tag("lake_rock")


static func ids_with_tag(tag: String) -> Array[String]:
	var ids: Array[String] = []
	for item in Catalog.all("props"):
		if item.tags.has(tag):
			ids.append(item.id)
	return ids


static func building_dimensions() -> Dictionary:
	var result := {}
	for item in Catalog.all("props"):
		if item.tags.has("building") and not item.tags.has("rural"):
			result[item.id] = item.base_size
	return result


static func definition(id: String) -> Resource:
	var item: Resource = Catalog.find("props", id)
	return item if item != null else Catalog.find("props", "fallback")


static func build(id: String) -> ArrayMesh:
	var item: Resource = definition(id)
	var mesh: ArrayMesh
	if not item.builder_path.is_empty():
		mesh = load(item.builder_path).build(item)
	elif not item.scene_path.is_empty():
		mesh = SceneSource.prop_mesh(item.scene_path)
	else:
		var source: Mesh = load(item.source_mesh_path)
		mesh = SceneSource.array_mesh(source, Transform3D.IDENTITY, source.surface_get_material(0))
	return Geometry.metre_mesh(mesh, item.metre_scale, item.target_height)
