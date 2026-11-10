extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for i in range(3):
		Geometry.column(st,Vector3(i*9.5-9.5,4.2,0),8.4,4.2,4.2,Color("d9d9d4") if i != 1 else Color("c4472f"),12)
		Geometry.column(st,Vector3(i*9.5-9.5,8.7,0),0.7,4.0,3.2,Color("9fa6a8"),12)
		Geometry.box(st,Vector3(i*9.5-9.5,4.2,4.3),Vector3(0.5,8.4,0.5),Color("6f777c"))
	Geometry.box(st,Vector3(0,9.6,0),Vector3(21,0.35,0.5),Color("6f777c"))
	st.index()
	return st.commit()
