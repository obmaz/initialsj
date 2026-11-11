extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 0.4, 0), Vector3(3, 0.8, 3), Color("c5aa75"))
	Geometry.column(st, Vector3(0, 4.5, 0), 7.4, 1, 0.7, Color("d7ba7b"), 4)
	Geometry.column(st, Vector3(0, 8.8, 0), 1.3, 0.7, 0, Color("e5cf93"), 4)
	st.index()
	return st.commit()
