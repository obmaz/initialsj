extends Node3D

const WIDTH := 18.0
const Scenery = preload("res://scripts/fuji_environment.gd")
const ASPHALT = preload("res://assets/environment/asphalt.png")
const ASPHALT_SHADER = preload("res://shaders/asphalt.gdshader")
const PAINT_SHADER = preload("res://shaders/road_paint.gdshader")
const SKID_SHADER = preload("res://shaders/skid_marks.gdshader")
var scenery: Scenery
var road_surface: MeshInstance3D
var skid_meshes: Array[MeshInstance3D] = []
var prop_batches: Array[MultiMeshInstance3D] = []
var curve := Curve3D.new()
var length := 0.0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	curve.bake_interval = 2.0
	for i in range(361):
		var a := TAU * i / 360.0
		curve.add_point(Vector3(sin(a) * (260.0 + 32.0 * sin(a * 3.0)), 6.0 + 5.0 * sin(a * 2.0), cos(a) * 330.0))
	length = curve.get_baked_length()

func point(distance: float, lane: float = 0.0) -> Vector3:
	var d := fposmod(distance, length)
	var p := curve.sample_baked(d)
	var forward := (curve.sample_baked(fposmod(d + 1.0, length)) - p).normalized()
	return p + Vector3(-forward.z, 0, forward.x) * lane

func heading(distance: float) -> float:
	var f := point(distance + 1.0) - point(distance)
	return atan2(-f.x, -f.z)

func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.65 if metallic == 0 else 0.28
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func strip(left: float, right: float, height: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(900):
		var a := length * i / 900.0
		var b := length * (i + 1) / 900.0
		var points := [point(a, left), point(a, right), point(b, left), point(b, right)]
		var uvs := [Vector2(left / 6, a / 6), Vector2(right / 6, a / 6), Vector2(left / 6, b / 6), Vector2(right / 6, b / 6)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.set_uv(uvs[index])
			st.add_vertex(points[index] + Vector3.UP * height)
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	add_child(n)
	return n

func paint(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	mat.set_shader_parameter("paint_color", color)
	return mat

func _ready() -> void:
	rng.seed = 8417
	var asphalt := ShaderMaterial.new()
	asphalt.shader = ASPHALT_SHADER
	asphalt.set_shader_parameter("asphalt_texture", ASPHALT)
	strip(-10, 10, -0.15, material(Color("7e8477")))
	road_surface = strip(-9, 9, 0, asphalt)
	road_surface.name = "TexturedAsphalt"
	strip(-8.6, -8.4, 0.025, paint(Color("e7e6d6")))
	strip(8.4, 8.6, 0.025, paint(Color("e7e6d6")))
	var yellow := paint(Color("dfc76d"))
	strip(-0.13, 0.0, 0.025, yellow)
	strip(0.15, 0.28, 0.025, yellow)
	var red := paint(Color("c94c48"))
	var white := paint(Color("e9e7db"))
	var steel := material(Color("8d9c9c"), 0.6)
	var rail_transforms: Array[Transform3D] = []
	var post_transforms: Array[Transform3D] = []
	var red_transforms: Array[Transform3D] = []
	var white_transforms: Array[Transform3D] = []
	for i in range(int(length / 5)):
		var d := i * 5.0
		for side in [-1, 1]:
			rail_transforms.append(Transform3D(Basis(Vector3.UP, heading(d)), point(d, side * 10.5) + Vector3.UP * 0.9))
			if i % 3 == 0:
				post_transforms.append(Transform3D(Basis.IDENTITY, point(d, side * 10.5) + Vector3.UP * 0.4))
	for i in range(int(length / 3)):
		var d := i * 3.0
		for side in [-1, 1]:
			var transform := Transform3D(Basis(Vector3.UP, heading(d)), point(d, side * 9.1))
			if i % 2 == 0:
				red_transforms.append(transform)
			else:
				white_transforms.append(transform)
	box_batch(Vector3(0.18, 0.45, 5.15), steel, rail_transforms)
	box_batch(Vector3(0.16, 1.0, 0.16), steel, post_transforms)
	box_batch(Vector3(0.7, 0.13, 3.05), red, red_transforms)
	box_batch(Vector3(0.7, 0.13, 3.05), white, white_transforms)
	make_curve_markers()
	make_skid_marks()
	scenery = Scenery.new()
	scenery.track = self
	add_child(scenery)
	make_course_banners()
	# Starting stripe and a welcome gantry farther along the lakeside road.
	for i in range(18):
		for row in range(2):
			var tile := box(self, point(row * 1.2, i - 8.5) + Vector3.UP * 0.035, Vector3(1, 0.025, 1.2), white if (i + row) % 2 == 0 else asphalt)
			tile.rotation.y = heading(0)
	var gantry := Node3D.new()
	add_child(gantry)
	gantry.position = point(110)
	gantry.rotation.y = heading(110)
	for side in [-1, 1]:
		box(gantry, Vector3(side * 11, 4.5, 0), Vector3(0.5, 9, 0.5), steel)
	box(gantry, Vector3(0, 8.5, 0), Vector3(23, 2.2, 0.6), material(Color("122a40")))
	var sign_label := Label3D.new()
	sign_label.text = "INITIAL SJ  /  FUJI LAKESIDE"
	sign_label.font_size = 90
	sign_label.pixel_size = 0.008
	sign_label.position = Vector3(0, 8.5, 0.35)
	gantry.add_child(sign_label)

func make_skid_marks() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SKID_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	for run in range(12):
		var start := length * (0.012 + run * 0.078)
		var run_length := 65.0 + 20.0 * sin(run * 2.1)
		var direction := -1.0 if run % 2 == 0 else 1.0
		for wheel in [-1, 1]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for segment in range(36):
				var t0 := segment / 36.0
				var t1 := (segment + 1) / 36.0
				var a := start + t0 * run_length
				var b := start + t1 * run_length
				var lane_a: float = direction * (1.1 + sin(t0 * PI) * 2.7) + wheel * 0.79
				var lane_b: float = direction * (1.1 + sin(t1 * PI) * 2.7) + wheel * 0.79
				var vertices := [point(a, lane_a - 0.14), point(a, lane_a + 0.14), point(b, lane_b - 0.14), point(b, lane_b + 0.14)]
				var uvs := [Vector2(0, t0), Vector2(1, t0), Vector2(0, t1), Vector2(1, t1)]
				for index in [0, 2, 1, 1, 2, 3]:
					st.set_uv(uvs[index])
					st.set_normal(Vector3.UP)
					st.add_vertex(vertices[index] + Vector3.UP * 0.038)
			var node := MeshInstance3D.new()
			node.mesh = st.commit()
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			skid_meshes.append(node)

func box_batch(size: Vector3, mat: Material, transforms: Array[Transform3D]) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = mat
	add_child(node)
	prop_batches.append(node)

func make_curve_markers() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/environment/curve-chevron.svg")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3, 1.5)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = int(length / 65)
	for i in range(instances.instance_count):
		var d := 35.0 + i * 65.0
		var bend := wrapf(heading(d + 40) - heading(d), -PI, PI)
		var side := 1.0 if bend > 0 else -1.0
		var basis := Basis(Vector3.UP, heading(d)).scaled(Vector3(side, 1, 1))
		instances.set_instance_transform(i, Transform3D(basis, point(d, side * 11.5) + Vector3.UP * 1.9))
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func make_course_banners() -> void:
	var poles: Array[Transform3D] = []
	var flags := MultiMesh.new()
	flags.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.6, 6.4)
	mesh.subdivide_depth = 10
	flags.mesh = mesh
	flags.instance_count = int(length / 95) * 2
	for i in range(flags.instance_count):
		var d := 55.0 + floori(i / 2.0) * 95.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var base: Vector3 = scenery.terrain_point(d, side * 13.8)
		poles.append(Transform3D(Basis.IDENTITY, base + Vector3.UP * 3.8))
		var center := point(d, side * 13.0)
		center.y = base.y + 4.3
		flags.set_instance_transform(i, Transform3D(Basis(Vector3.UP, heading(d)).scaled(Vector3(-side, 1, 1)), center))
	box_batch(Vector3(0.08, 7.6, 0.08), material(Color("899aa1"), 0.6), poles)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/course_banner.gdshader")
	var node := MultiMeshInstance3D.new()
	node.multimesh = flags
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
