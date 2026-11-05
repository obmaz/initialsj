extends Node3D

const PANORAMA = preload("res://assets/environment/fuji-lake-panorama.png")
const PINE = preload("res://assets/environment/japanese-pine.png")
const SAKURA = preload("res://assets/environment/sakura-tree.png")
const GRASS = preload("res://assets/environment/lakeside-grass.png")
const ASPHALT = preload("res://assets/environment/asphalt.png")
const SKY_SHADER = preload("res://shaders/fuji_sky.gdshader")
const TERRAIN_SHADER = preload("res://shaders/lakeside_terrain.gdshader")
const WATER_SHADER = preload("res://shaders/lake_water.gdshader")
const WATER_HEIGHT := 0.0
const SHORE_LANE := -18.0
var track: Node3D
var water: MeshInstance3D
var tree_positions: Array[Vector3] = []
var tree_batches: Array[MultiMeshInstance3D] = []
var tree_materials: Array[StandardMaterial3D] = []
var rng := RandomNumberGenerator.new()

func make_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("panorama", PANORAMA)
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky

func terrain_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(distance, lane)
	var road_y: float = track.point(distance).y
	if lane < -10:
		p.y = lerpf(WATER_HEIGHT + 0.12, road_y - 0.25, clampf((lane - SHORE_LANE) / (-10.0 - SHORE_LANE), 0, 1))
	else:
		p.y = road_y - 0.25 + maxf(0, lane - 12) * 0.03
	return p

func _ready() -> void:
	rng.seed = 8417
	var terrain := ShaderMaterial.new()
	terrain.shader = TERRAIN_SHADER
	terrain.set_shader_parameter("ground_grain", GRASS)
	terrain_band(SHORE_LANE, -10, terrain)
	terrain_band(10, 110, terrain)
	make_water()
	for source in [PINE, SAKURA]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = source
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.28
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tree_materials.append(mat)
	make_trees()

func terrain_band(inner: float, outer: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(450):
		var a: float = track.length * i / 450.0
		var b: float = track.length * (i + 1) / 450.0
		var points := [terrain_point(a, inner), terrain_point(a, outer), terrain_point(b, inner), terrain_point(b, outer)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(points[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	add_child(node)

func make_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(450):
		var a: Vector3 = track.point(track.length * i / 450.0, SHORE_LANE)
		var b: Vector3 = track.point(track.length * (i + 1) / 450.0, SHORE_LANE)
		a.y = WATER_HEIGHT
		b.y = WATER_HEIGHT
		for point: Vector3 in [Vector3(0, WATER_HEIGHT, 0), b, a]:
			st.set_normal(Vector3.UP)
			st.add_vertex(point)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("lake_image", PANORAMA)
	water = MeshInstance3D.new()
	water.name = "KawaguchiLake"
	water.mesh = st.commit()
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func make_trees() -> void:
	var shadow_texture := GradientTexture2D.new()
	shadow_texture.width = 64
	shadow_texture.height = 64
	shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	shadow_texture.fill_from = Vector2(0.5, 0.5)
	shadow_texture.fill_to = Vector2(1, 0.5)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("08110a50"))
	gradient.set_color(1, Color("08110a00"))
	shadow_texture.gradient = gradient
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_texture = shadow_texture
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pine_transforms: Array[Transform3D] = []
	var sakura_transforms: Array[Transform3D] = []
	var shadow_transforms: Array[Transform3D] = []
	for i in range(170):
		var d: float = i * track.length / 170.0 + rng.randf_range(-3, 3)
		var lakeside := i % 6 == 0
		var outer_belt := i % 4 == 1
		var lane := rng.randf_range(-16, -14) if lakeside else rng.randf_range(65 if outer_belt else 19, 100 if outer_belt else 55)
		var p := terrain_point(d, lane)
		var is_sakura := i % 5 == 0 or lakeside
		var source: Texture2D = SAKURA if is_sakura else PINE
		var height := rng.randf_range(6.5, 9) if is_sakura else rng.randf_range(14 if outer_belt else 9, 22 if outer_belt else 16)
		var size := Vector3(height * source.get_width() / source.get_height(), height, 1)
		var transform := Transform3D(Basis.IDENTITY.scaled(size), p + Vector3.UP * (height * 0.5 - 0.16))
		if is_sakura:
			sakura_transforms.append(transform)
		else:
			pine_transforms.append(transform)
		tree_positions.append(p)
		var shadow_basis := Basis(Vector3.UP, -0.5).scaled(Vector3(height * 0.6, 1, height * 1.1))
		shadow_transforms.append(Transform3D(shadow_basis, p + Vector3(1.5, 0.04, 2.5)))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	make_batch(quad, tree_materials[0], pine_transforms)
	make_batch(quad, tree_materials[1], sakura_transforms)
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2.ONE
	make_batch(shadow_plane, shadow_mat, shadow_transforms)

func make_batch(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	tree_batches.append(node)
