extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,0.3,0),Vector3(10,0.6,8),Color("777e70"))
	Geometry.box(st,Vector3(0,2.2,0),Vector3(8,3.8,6),Color("d5c4a5"),0,7)
	for side in [-1,1]:
		Geometry.box(st,Vector3(side*3.8,2,3.1),Vector3(0.28,3.6,0.25),Color("77523e"))
	Geometry.column(st,Vector3(0,4.5,0),2.0,6.7,2.1,Color("3f5755"),4)
	Geometry.architectural_mass(st,definition.base_size,definition.parameters.mass_offset,definition.parameters.floors,definition.parameters.columns)
	st.index()
	return st.commit()
