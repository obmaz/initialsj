extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 4.3, 0), Vector3(17, 8.6, 9), Color("e9e1cf"), 0, 6)
	Geometry.box(st, Vector3(0, 5.2, 0), Vector3(19, 0.5, 11), Color("4a5760"))
	Geometry.box(st, Vector3(0, 9.0, 0), Vector3(17, 0.6, 10), Color("4a5760"))
	Geometry.box(st, Vector3(0, 9.7, 0), Vector3(9, 0.8, 8), Color("3f4a52"))
	Geometry.architectural_mass(
		st,
		definition.base_size,
		definition.parameters.mass_offset,
		definition.parameters.floors,
		definition.parameters.columns
	)
	st.index()
	return st.commit()
