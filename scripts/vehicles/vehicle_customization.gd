extends RefCounted
const Parts = preload("res://models/model_catalog.gd")
const Source = preload("res://models/shared/scene_source.gd")
const LIVERY = preload("res://shaders/vehicle_livery.gdshader")
const WHEEL = preload("res://shaders/tuning_wheel.gdshader")
const ATLAS := "res://models/shared/vehicle_liveries/atlas.png"
const WHEELS := ["stock", "five_spoke", "split_spoke"]
const WINGS := ["stock", "ducktail", "gt_wing", "none"]


static func paint_material(color: Color, source_texture: Texture2D = null) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LIVERY
	material.set_shader_parameter("base_paint", Vector4(color.r, color.g, color.b, 1))
	material.set_shader_parameter("use_source_texture", source_texture != null)
	material.set_shader_parameter("source_texture", source_texture)
	return material


static func part_mesh(id: String) -> Mesh:
	var definition: Resource = Parts.find("vehicle_parts", id)
	var root := Source.instantiate_static(definition.scene_path)
	var mesh: Mesh = Source.collect_meshes(root)[0].mesh
	root.free()
	return mesh


static func cached_part(car: Node3D, id: String) -> Mesh:
	var meshes: Dictionary = car.get_meta("tuning_part_meshes", {})
	if not meshes.has(id):
		meshes[id] = part_mesh(id)
		car.set_meta("tuning_part_meshes", meshes)
	return meshes[id]


static func apply(car: Node3D, data: Dictionary, vehicle: int) -> void:
	car.equipped_effects = preload("res://scripts/vehicles/effect_items.gd").sanitize(data.get("effects", []), vehicle)
	if car.boost_fx != null:
		car.boost_fx.mega = "mega_exhaust" in car.equipped_effects
	var open_top: bool = "open_top" in car.equipped_effects
	if car.has_meta("open_top_variants"):
		var variants: Dictionary = car.get_meta("open_top_variants")
		if not car.has_meta("closed_top_meshes"):
			car.set_meta(
				"closed_top_meshes",
				{"PaintShell": car.body.get_node("PaintShell").mesh, "TrimShell": car.body.get_node("TrimShell").mesh}
			)
		for name in ["PaintShell", "TrimShell"]:
			car.body.get_node(NodePath(name)).mesh = (
				variants["Open" + name].mesh if open_top else car.get_meta("closed_top_meshes")[name]
			)
		var cabin: MeshInstance3D = car.body.get_node_or_null("OpenCabin")
		if cabin == null and open_top:
			cabin = MeshInstance3D.new()
			cabin.name = "OpenCabin"
			cabin.mesh = variants.OpenCabin.mesh
			cabin.transform = variants.OpenCabin.transform
			cabin.material_override = car.paint_material()
			car.body.add_child(cabin)
		if cabin != null:
			cabin.visible = open_top
	car.set_protection(false)
	car.protection_parts.clear()
	car.protection_originals.clear()
	car.protection_materials.clear()
	var previous: Dictionary = car.get_meta("tuning_state", {})
	var color := Color(data.paint)
	car.paint = color
	for part in car.body.get_children():
		if part is MeshInstance3D and part not in car.wheels:
			var material: Material = part.material_override
			if material is ShaderMaterial and material.shader == car.shared_body_material().shader:
				material.set_shader_parameter("traffic_paint", Vector4(color.r, color.g, color.b, 1))
	var shell: MeshInstance3D = car.body.get_node_or_null("PaintShell")
	if shell != null:
		var material: ShaderMaterial = shell.material_override
		if material == null or material.shader != LIVERY:
			material = paint_material(color)
			shell.material_override = material
		material.set_shader_parameter("base_paint", Vector4(color.r, color.g, color.b, 1))
		var secondary := Color(data.secondary)
		material.set_shader_parameter("secondary_paint", Vector4(secondary.r, secondary.g, secondary.b, 1))
		material.set_shader_parameter("livery", data.livery)
		material.set_shader_parameter("vehicle_column", vehicle)
		material.set_shader_parameter("finish_roughness", [.25, .8, .32][data.finish])
		material.set_shader_parameter("finish_metallic", [.35, .05, .85][data.finish])
		material.set_shader_parameter("livery_atlas", load(ATLAS) if data.livery > 0 else null)
	var rim := Color(data.rim)
	var wheel_material: ShaderMaterial = (
		car.get_meta("tuning_wheel_material") if car.has_meta("tuning_wheel_material") else null
	)
	if wheel_material == null:
		wheel_material = ShaderMaterial.new()
		wheel_material.shader = WHEEL
		car.set_meta("tuning_wheel_material", wheel_material)
	var overlay_material: ShaderMaterial = (
		car.get_meta("tuning_rim_material") if car.has_meta("tuning_rim_material") else null
	)
	if overlay_material == null:
		overlay_material = ShaderMaterial.new()
		overlay_material.shader = WHEEL
		overlay_material.set_shader_parameter("overlay", true)
		car.set_meta("tuning_rim_material", overlay_material)
	for material in [wheel_material, overlay_material]:
		material.set_shader_parameter("rim_color", Vector4(rim.r, rim.g, rim.b, 1))
	if car.body.has_meta("source_texture"):
		wheel_material.set_shader_parameter("use_source_texture", true)
		wheel_material.set_shader_parameter("source_texture", car.body.get_meta("source_texture"))
	wheel_material.set_shader_parameter("replace_rim", data.wheel > 0)
	if previous.get("wheel", -1) != data.wheel:
		var mesh: Mesh = cached_part(car, WHEELS[data.wheel]) if data.wheel > 0 else null
		for wheel in car.wheels:
			for name in ["TuningRim", "TuningRimInner"]:
				var old: Node = wheel.get_node_or_null(name)
				if old != null:
					old.free()
			wheel.material_override = wheel_material
			if mesh != null:
				var cover := MeshInstance3D.new()
				cover.name = "TuningRim"
				cover.mesh = mesh
				cover.material_override = overlay_material
				cover.scale = Vector3.ONE * car.wheel_radius
				cover.position.y = car.wheel_thickness * .5 + .012
				wheel.add_child(cover)
				var inner := cover.duplicate() as MeshInstance3D
				inner.name = "TuningRimInner"
				inner.position.y = -cover.position.y
				inner.rotation.x = PI
				wheel.add_child(inner)
	if not car.has_meta("tuning_aero_recorded"):
		car.set_meta("tuning_aero_recorded", true)
		if car.active_aero != null:
			car.set_meta("stock_aero", car.active_aero)
		car.set_meta("stock_aero_rest", car.aero_rest)
	if previous.get("wing", -1) != data.wing:
		var stock: MeshInstance3D = car.get_meta("stock_aero") if car.has_meta("stock_aero") else null
		var old: Node = car.body.get_node_or_null("TuningWing")
		if old != null:
			old.free()
		if is_instance_valid(stock):
			stock.visible = data.wing == 0
		car.active_aero = stock if data.wing == 0 else null
		car.aero_rest = car.get_meta("stock_aero_rest")
		if data.wing in [1, 2]:
			var wing := MeshInstance3D.new()
			wing.name = "TuningWing"
			wing.mesh = cached_part(car, WINGS[data.wing])
			wing.position = car.aero_rest.origin
			wing.scale = Vector3(car.wheel_half_track * 1.9, 1, 1)
			wing.material_override = car.paint_material()
			car.body.add_child(wing)
			car.active_aero = wing
			car.aero_rest = wing.transform
		if car.active_aero != null:
			car.active_aero.transform = car.aero_rest
		car.aero_blend = 0
	car.set_meta("tuning_state", data.duplicate(true))
