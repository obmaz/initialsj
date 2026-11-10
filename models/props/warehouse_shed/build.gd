extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,3.2,0),Vector3(14,6.4,26),Color("8c97a0"),0,5)
	Geometry.box(st,Vector3(0,6.8,0),Vector3(14.6,0.5,26.6),Color("5f6a73"))
	Geometry.box(st,Vector3(0,7.3,0),Vector3(7,0.9,26.2),Color("6f7b84"))
	for z in [-9.0,-3.0,3.0,9.0]: Geometry.box(st,Vector3(7.05,3,z),Vector3(0.1,5.2,0.35),Color("6e7983"))
	Geometry.box(st,Vector3(7.08,2.2,0),Vector3(0.1,4.2,5),Color("d9a73a"))
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
