extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var steel := Color("e08a2c")
	for x in [-8.0, 8.0]:
		for z in [-4.0, 4.0]:
			Geometry.column(st, Vector3(x, 12, z), 24, 0.7, 0.5, steel, 6)
	for z in [-4.0, 4.0]:
		Geometry.box(st, Vector3(0, 23, z), Vector3(17, 1.6, 1.4), steel)
	Geometry.box(st, Vector3(0, 12, -4), Vector3(16, 0.5, 0.5), steel.darkened(0.15))
	Geometry.box(st, Vector3(0, 12, 4), Vector3(16, 0.5, 0.5), steel.darkened(0.15))
	Geometry.box(st, Vector3(0, 25.2, 0), Vector3(5, 3, 10), Color("c8c9c2"))
	Geometry.box(st, Vector3(0, 24.9, -23), Vector3(2.2, 2.0, 38), steel)
	Geometry.box(st, Vector3(0, 24.9, 22), Vector3(2.2, 2.0, 12), steel)
	for x in [-1.1, 1.1]:
		Geometry.box(st, Vector3(x, 16, -10), Vector3(0.2, 17, 0.2), Color("3a3f44"))
	Geometry.box(st, Vector3(0, 12, -10), Vector3(3, 1.8, 6), Color("3d6f9e"))
	Geometry.box(st, Vector3(0, 27.5, 0), Vector3(1.2, 1.2, 1.2), Color("e8332a"))
	st.index()
	return st.commit()
