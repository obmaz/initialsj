extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for x in [-3.0,3.0]: Geometry.column(st,Vector3(x,5,0),10,0.28,0.24,Color("6f777c"),6)
	Geometry.box(st,Vector3(0,10.4,0),Vector3(10.5,5.2,0.5),Color("33383d"))
	Geometry.box(st,Vector3(0,10.4,0.28),Vector3(10,4.7,0.1),Color("f3f0e4"),0,20)
	st.index()
	return st.commit()
