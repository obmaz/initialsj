extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,5.4,0),Vector3(14,0.7,9),Color("f2f2ee"))
	Geometry.box(st,Vector3(0,5.0,0),Vector3(14.2,0.35,9.2),Color("d6342b"))
	for x in [-5.5,5.5]:
		for z in [-3.2,3.2]: Geometry.column(st,Vector3(x,2.6,z),5.2,0.16,0.16,Color("c9ccce"),6)
	for x in [-2.6,2.6]:
		Geometry.box(st,Vector3(x,.8774,0),Vector3(.625,1.4348,.4118),Color("d6342b"))
		Geometry.box(st,Vector3(x,1.3478,0),Vector3(.6438,.3043,.4235),Color("1c2b36"))
		Geometry.box(st,Vector3(x,.08,0),Vector3(.78125,.16,2.3529),Color("8e948f"))
	Geometry.box(st,Vector3(0,1.7,-8),Vector3(8,3.4,4.5),Color("d8d5c8"),0,3)
	Geometry.box(st,Vector3(0,3.6,-8),Vector3(8.4,0.4,4.9),Color("d6342b"))
	Geometry.column(st,Vector3(8.5,4.5,3.5),9.0,0.14,0.14,Color("737a7e"),6)
	Geometry.box(st,Vector3(8.5,8.6,3.5),Vector3(3.2,2.8,0.4),Color("ffd34a"))
	Geometry.box(st,Vector3(8.5,8.6,3.72),Vector3(2.7,0.6,0.1),Color("d6342b"))
	Geometry.box(st,Vector3(0,0.06,-1),Vector3(17,0.12,17),Color("5e6468"))
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
