extends Node
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var textures: Array[Texture2D] = []
var viewports: Array[SubViewport] = []
var rendered := []
# Set before the node enters the tree: weak GPUs (game consoles) get smaller, unsmoothed previews.
var lite := false


func _ready() -> void:
	for i in range(Catalog.SPECS.size()):
		rendered.append(false)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 314) if lite else Vector2i(880, 432)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_DISABLED if lite else Viewport.MSAA_2X
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		viewports.append(viewport)
		var world := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("dceaff")
		env.ambient_light_energy = 0.45
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world.environment = env
		viewport.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42, -35, 0)
		sun.light_energy = 1.05
		sun.light_color = Color("ffe3bd")
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 25
		viewport.add_child(sun)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, 140, 0)
		fill.light_color = Color("79c8f1")
		fill.light_energy = 0.35
		viewport.add_child(fill)
		var platform := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(3.4, 5.3)
		platform.mesh = mesh
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.01, 0.02, 0.03, 0.7))
		gradient.set_color(1, Color(0.01, 0.02, 0.03, 0))
		var shadow := GradientTexture2D.new()
		shadow.width = 64
		shadow.height = 64
		shadow.gradient = gradient
		shadow.fill = GradientTexture2D.FILL_RADIAL
		shadow.fill_from = Vector2(0.5, 0.5)
		shadow.fill_to = Vector2(1, 0.5)
		var material := StandardMaterial3D.new()
		material.albedo_texture = shadow
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		platform.material_override = material
		platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(platform)
		var car := Factory.create(i)
		car.position.y = 0.12
		viewport.add_child(car)
		var camera := Camera3D.new()
		camera.position = Vector3(-3.5, 1.9, -4.8)
		camera.fov = 30
		viewport.add_child(camera)
		camera.look_at(Vector3(0, 0.72, 0))
		textures.append(viewport.get_texture())


func show_vehicle(index: int) -> void:
	if not rendered[index]:
		viewports[index].render_target_update_mode = SubViewport.UPDATE_ONCE
		rendered[index] = true
