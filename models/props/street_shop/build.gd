extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var kind: String = str(definition.id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 2.2, 0), Vector3(7, 4.4, 6), Color("b4b2a0"), 0, 8 if kind == "ticket_booth" else 2)
	Geometry.box(
		st, Vector3(0, 4.5, 1), Vector3(8, 0.5, 8), Color("cb654a") if kind == "street_shop" else Color("d595b6")
	)
	Geometry.box(st, Vector3(0, 5.1, 3.7), Vector3(5, 0.8, 0.18), Color("e1cc90"))
	Geometry.box(st, Vector3(0, 0.15, 0), Vector3(8, 0.3, 7), Color("858c87"))
	Geometry.architectural_mass(
		st,
		definition.base_size,
		definition.parameters.mass_offset,
		definition.parameters.floors,
		definition.parameters.columns
	)
	st.index()
	return st.commit()
