extends Node3D
const Catalog = preload("res://scripts/route_prop_catalog.gd")
const ATLAS = preload("res://assets/environment/route-props.png")
var scenery: Node3D
var positions: Array[Vector3] = []
var sprite_batch: MultiMeshInstance3D
func _ready() -> void:
	var theme: String = scenery.theme
	var road: Node3D = scenery.track
	var region: Vector4 = Catalog.REGIONS[theme]
	var random := RandomNumberGenerator.new()
	random.seed = 2026+road.stage*137+road.route_node*47
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	var spacing := 95.0 if theme in ["city","seoul","neon","ruins","canyon"] else 45.0
	var count := int((road.length-350)/spacing)
	multi.instance_count = count
	var shadows: Array[Transform3D] = []
	for i in range(count):
		var d: float = 240+i*spacing+random.randf_range(-8,8)
		var side := -1.0 if i%2 == 0 else 1.0
		if road.entry_side != 0 and d < 650: side = float(road.entry_side)
		if theme in ["hawaii","jeju","fuji"]: side = 1.0
		var h: float = Catalog.HEIGHTS[theme]*random.randf_range(0.8,1.25)
		var w := h*region.z/region.w
		var lane: float = side*(road.half_width(d)+5+w*0.5+random.randf_range(0,12))
		if theme == "canyon": lane += side*28
		var p: Vector3 = scenery.terrain_point(d,lane)
		positions.append(p)
		var flip := -1.0 if i%3 == 0 else 1.0
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled_local(Vector3(w,h,1)),p+Vector3.UP*(h*0.5-maxf(0.1,h*(0.05 if theme == "canyon" else 0.015)))))
		multi.set_instance_custom_data(i,Color(region.x+(region.z if flip < 0 else 0),region.y,region.z*flip,region.w))
		shadows.append(Transform3D(Basis.IDENTITY.scaled_local(Vector3(w*0.75,1,w*0.4)),p+Vector3.UP*0.025))
	sprite_batch = MultiMeshInstance3D.new()
	sprite_batch.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/roadside_sprite.gdshader")
	material.set_shader_parameter("atlas",ATLAS)
	sprite_batch.material_override = material
	sprite_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite_batch)
	make_shadows(shadows)
func make_shadows(poses: Array[Transform3D]) -> void:
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.03,0.05,0.04,0.20))
	gradient.set_color(1,Color(0.03,0.05,0.04,0))
	texture.gradient = gradient
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	scenery.batch(plane,material,poses,false)
