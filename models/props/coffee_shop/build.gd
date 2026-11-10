extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,1.9,0),Vector3(8,3.8,6),Color("b08a5e"),0,0)
	Geometry.box(st,Vector3(0,3.95,0),Vector3(9,0.4,7),Color("4f3d30"))
	for i in range(6): Geometry.box(st,Vector3(-3.75+i*1.5,3.2,4.2),Vector3(1.5,0.14,2.0),Color("2f8a5a") if i%2 == 0 else Color("f3eadb"),0.0)
	Geometry.box(st,Vector3(-4.7,5.6,2.6),Vector3(0.12,1.8,0.12),Color("4f3d30"))
	Geometry.box(st,Vector3(-4.7,5.7,2.9),Vector3(0.2,1.5,1.5),Color("f6f1e6"))
	Geometry.round_part(st,Vector3(-4.7,5.5,3.7),Vector3(0.5,0.6,0.5),Color("6a4528"))
	Geometry.box(st,Vector3(0,0.1,5.8),Vector3(9,0.2,4),Color("9a7a52"))
	for x in [-2.6,2.6]:
		Geometry.column(st,Vector3(x,0.7,5.8),1.4,0.35,0.35,Color("f3eadb"),8)
		Geometry.column(st,Vector3(x,2.2,5.8),2.6,0.04,0.04,Color("5b5148"),5)
		Geometry.column(st,Vector3(x,3.3,5.8),0.5,1.6,0.0,Color("d6452f") if x < 0 else Color("2f8a5a"),8)
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
