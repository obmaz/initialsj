extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func rope_point(strand: int, t: float) -> Vector3:
	return Vector3(
		(strand - 1.5) * 1.65 + sin(t * 7 + strand) * .6, 12 - t * (9.8 - strand * .65), sin(t * 6 + strand) * .65
	)


static func build(_definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(4):
		for i in range(20):
			var a := rope_point(strand, float(i) / 20)
			var b := rope_point(strand, float(i + 1) / 20)
			var rope := CylinderMesh.new()
			rope.top_radius = .065
			rope.bottom_radius = .085
			rope.height = a.distance_to(b)
			rope.radial_segments = 5
			rope.rings = 1
			var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
			Geometry.append(st, rope, Transform3D(basis, (a + b) * .5), Color("7d8467"))
		for i in range(15):
			var center := rope_point(strand, .04 + float(i) / 16)
			var basis := Basis(Vector3.UP, i * 2.4 + strand).rotated(Vector3.RIGHT, .3 * sin(i))
			st.set_uv2(Vector2.ONE)
			st.set_color(Color("7e986b") if i % 3 else Color("a6b08a"))
			for index in [0, 2, 1, 1, 2, 3]:
				var p := Vector3(-.85 if index % 2 == 0 else .85, -.65 if index < 2 else .65, .10 if index == 3 else 0)
				st.set_uv(Vector2(0 if index % 2 == 0 else 1, 1 if index < 2 else 0))
				st.set_normal(basis * Vector3.BACK)
				st.add_vertex(center + basis * p)
	st.index()
	return st.commit()
