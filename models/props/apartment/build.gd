extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var wall := Color("c9bfae")
	Geometry.box(st, Vector3(0, 8.5, 0), Vector3(11, 17, 9), wall, 0, 4)
	Geometry.box(st, Vector3(0, 17.2, 0), Vector3(11.6, 0.5, 9.6), Color("8d8a82"))
	Geometry.architectural_mass(
		st,
		definition.base_size,
		definition.parameters.mass_offset,
		definition.parameters.floors,
		definition.parameters.columns
	)
	st.index()
	return st.commit()
