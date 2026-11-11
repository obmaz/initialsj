extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 2.5, 0), Vector3(5.2, 0.42, 2.2), Color("2a8aa3"))
	for x in [-2.4, 2.4]:
		Geometry.box(st, Vector3(x, 1.25, 0.9), Vector3(0.12, 2.5, 0.12), Color("3b4247"))
	Geometry.box(st, Vector3(0, 1.3, -0.95), Vector3(4.8, 2.2, 0.22), Color("a7c9d4"), 0, 9)
	Geometry.box(st, Vector3(0, 0.55, -0.5), Vector3(3.6, 0.14, 0.7), Color("7a5638"))
	Geometry.box(st, Vector3(2.8, 1.6, 0.9), Vector3(0.1, 3.2, 0.1), Color("3b4247"))
	Geometry.box(st, Vector3(2.8, 3.0, 0.9), Vector3(0.9, 0.9, 0.1), Color("2a8aa3"))
	st.index()
	return st.commit()
