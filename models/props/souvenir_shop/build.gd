extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,1.8,0),Vector3(9,3.6,6),Color("efe7d6"),0,13)
	Geometry.box(st,Vector3(0,3.9,0.2),Vector3(10,0.45,7.4),Color("b8432f"))
	Geometry.box(st,Vector3(0,4.45,-0.2),Vector3(7,0.5,5),Color("a63a29"))
	for i in range(4):
		var x := -4.2+i*2.8
		Geometry.box(st,Vector3(x,3.0,5.2),Vector3(0.1,6.0,0.1),Color("4f4a45"))
		Geometry.box(st,Vector3(x+0.45,3.9,5.2),Vector3(0.8,3.4,0.05),Color("d6342b") if i%2 == 0 else Color("2c5fa6"))
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
