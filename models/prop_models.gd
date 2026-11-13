extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")
const SceneSource = preload("res://models/shared/scene_source.gd")
static var TREES: Array[String] = ids_with_tag("imported_tree")
static var PINES: Array[String] = ids_with_tag("lake_pine")
static var OAKS: Array[String] = ids_with_tag("lake_oak")
static var WILLOWS: Array[String] = ids_with_tag("lake_willow")
static var BUSHES: Array[String] = ids_with_tag("lake_bush")
static var ROCKS: Array[String] = ids_with_tag("lake_rock")


static func ids_with_tag(tag: String) -> Array[String]:
	var ids: Array[String] = []
	for model_definition in Catalog.all("props"):
		if model_definition.tags.has(tag):
			ids.append(model_definition.id)
	return ids


static func building_dimensions() -> Dictionary:
	var result := {}
	for model_definition in Catalog.all("props"):
		if model_definition.tags.has("building") and not model_definition.tags.has("rural"):
			result[model_definition.id] = model_definition.base_size
	return result


static func definition(id: String) -> Resource:
	var model_definition: Resource = Catalog.find("props", id)
	return model_definition if model_definition != null else Catalog.find("props", "fallback")


static func build(id: String) -> ArrayMesh:
	var model_definition: Resource = definition(id)
	var mesh := SceneSource.prop_mesh(model_definition.scene_path)
	if model_definition.parameters.get("vertex_facade", false):
		mesh.surface_set_material(0, null)
	return mesh
