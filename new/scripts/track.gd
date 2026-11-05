extends Node3D

const WIDTH := 18.0
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

func strip(left: float, right: float, height: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(900):
		var a := length * i / 900.0
		var b := length * (i + 1) / 900.0
		var points := [point(a, left), point(a, right), point(b, left), point(b, right)]
		for index in [0, 1, 2, 1, 3, 2]:
			st.add_vertex(points[index] + Vector3.UP * height)
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	add_child(n)

func _ready() -> void:
	rng.seed = 8417
	var asphalt := material(Color("303e4b"))
	asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED
	strip(-10, 10, -0.15, material(Color("c2b7a0")))
	strip(-9, 9, 0, asphalt)
	strip(-8.6, -8.4, 0.025, material(Color("eef0dd")))
	strip(8.4, 8.6, 0.025, material(Color("eef0dd")))
	var yellow := material(Color("efca67"))
	strip(-0.13, 0.0, 0.025, yellow)
	strip(0.15, 0.28, 0.025, yellow)
	var red := material(Color("df494a"))
	var white := material(Color("e9e7d9"))
	var steel := material(Color("8eabb4"), 0.6)
	for i in range(int(length / 5)):
		var d := i * 5.0
		for side in [-1, 1]:
			var curb := box(self, point(d, side * 9.1), Vector3(0.7, 0.15, 5.1), red if i % 2 == 0 else white)
			curb.rotation.y = heading(d)
			var rail := box(self, point(d, side * 10.5) + Vector3.UP * 0.9, Vector3(0.18, 0.45, 5.15), steel)
			rail.rotation.y = heading(d)
			if i % 3 == 0:
				box(self, point(d, side * 10.5) + Vector3.UP * 0.4, Vector3(0.16, 1.0, 0.16), steel)
	var ground := material(Color("457461"))
	box(self, Vector3(0, -6, 0), Vector3(2400, 4, 2400), ground)
	var water := material(Color("288dba"), 0.45)
	box(self, Vector3(0, -3.5, 0), Vector3(355, 1, 440), water)
	var pine := material(Color("245a4d"))
	var pine_light := material(Color("387866"))
	var trunk := material(Color("6c5442"))
	var blossom := material(Color("eeb5c7"))
	for i in range(240):
		var d := rng.randf_range(0, length)
		var side := -1.0 if i % 3 == 0 else 1.0
		var p := point(d, side * rng.randf_range(17, 65))
		p.y -= 3
		var h := rng.randf_range(7, 17)
		box(self, p + Vector3.UP * h * 0.35, Vector3(0.7, h * 0.7, 0.7), trunk)
		cone(p + Vector3.UP * h * 0.75, h * 0.35, h, blossom if i % 9 == 0 else (pine if i % 2 == 0 else pine_light), 7)
	for i in range(34):
		var a := TAU * i / 34.0
		var p := Vector3(sin(a) * 850, 20, cos(a) * 850)
		var h := rng.randf_range(160, 360)
		var radius := rng.randf_range(150, 220)
		cone(p, radius, h, material(Color("647f8e")), 6)
		cone(p + Vector3.UP * h * 0.323, radius * 0.365, h * 0.36, white, 6)
	# Finish gantry and chequered road stripe.
	for i in range(18):
		for row in range(2):
			var tile := box(self, point(row * 1.2, i - 8.5) + Vector3.UP * 0.035, Vector3(1, 0.025, 1.2), white if (i + row) % 2 == 0 else asphalt)
			tile.rotation.y = heading(0)
	var gantry := Node3D.new()
	add_child(gantry)
	gantry.position = point(0)
	gantry.rotation.y = heading(0)
	for side in [-1, 1]:
		box(gantry, Vector3(side * 11, 4.5, 0), Vector3(0.5, 9, 0.5), steel)
	box(gantry, Vector3(0, 8.5, 0), Vector3(23, 2.2, 0.6), material(Color("122a40")))
	var sign_label := Label3D.new()
	sign_label.text = "INITIAL SJ  /  ALPINE RUSH"
	sign_label.font_size = 90
	sign_label.pixel_size = 0.008
	sign_label.position = Vector3(0, 8.5, 0.35)
	gantry.add_child(sign_label)

func cone(pos: Vector3, radius: float, height: float, mat: Material, sides: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	add_child(n)
	n.position = pos
