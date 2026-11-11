extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for side in [-1, 1]:
		Geometry.column(st, Vector3(side * 2.6, 3.2, 0), 6.4, 0.32, 0.24, Color("bc493a"))
		Geometry.box(st, Vector3(side * 2.6, 0.3, 0), Vector3(1.2, 0.6, 1.2), Color("626762"))
	Geometry.box(st, Vector3(0, 5.0, 0), Vector3(6.3, 0.5, 0.5), Color("bf4b39"))
	Geometry.box(st, Vector3(0, 6.4, 0), Vector3(8.2, 0.5, 1.0), Color("393f3c"))
	Geometry.box(st, Vector3(0, 5.8, 0), Vector3(0.4, 0.9, 0.4), Color("d1a95c"))
	st.index()
	return st.commit()
