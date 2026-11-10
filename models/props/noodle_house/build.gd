extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,1.5,0),Vector3(9,3,7),Color("e4d9bf"),0,12)
	Geometry.box(st,Vector3(0,3.3,0),Vector3(11,0.4,9),Color("3d4348"))
	Geometry.box(st,Vector3(0,3.85,0),Vector3(8,0.7,6.4),Color("4a5158"))
	Geometry.box(st,Vector3(0,4.4,0),Vector3(4,0.5,5),Color("3d4348"))
	for x in [-3.5,3.5]:
		Geometry.round_part(st,Vector3(x,2.1,4.4),Vector3(0.7,1.0,0.7),Color("d6342b"))
		Geometry.box(st,Vector3(x,2.9,4.4),Vector3(0.06,0.9,0.06),Color("3a3a3a"))
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
