extends RefCounted
const Catalog = preload("res://models/model_catalog.gd")


static func count() -> int:
	return Catalog.all("buildings").size()


static func definition(style: int) -> Resource:
	return Catalog.all("buildings")[posmod(style, count())]


static func parts(style: int, width: float, height: float, depth: float) -> Array[Dictionary]:
	var item: Resource = definition(style)
	return load(item.builder_path).build(item, width, height, depth)


static func material(style: int, theme: String) -> Material:
	var definition: Resource = definition(style)
	if not definition.material_path.is_empty():
		return load(definition.material_path)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/building_facade.gdshader")
	material.set_shader_parameter("facade_images", load("res://assets/environment/urban-harbor-facades.png"))
	material.set_shader_parameter("facade_extra", load("res://assets/environment/urban-truck-elevations.png"))
	material.set_shader_parameter("ruined", theme == "ruins")
	material.set_shader_parameter("facade_style", definition.parameters.facade_index)
	material.set_shader_parameter("night_city", theme == "neon")
	material.set_shader_parameter("regional_style", 1 if theme == "seoul" else (2 if theme == "neon" else 0))
	return material
