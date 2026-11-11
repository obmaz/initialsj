extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.round_part(st, Vector3(0, 1, 0), Vector3(3, 2, 3), Color("596d59"))
	st.index()
	return st.commit()
