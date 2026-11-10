extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.column(st,Vector3(0,3,0),6,0.55,0.48,Color("718a4e"),7)
	for side in [-1,1]:
		Geometry.box(st,Vector3(side*0.8,2.8+side*0.5,0),Vector3(1.6,0.6,0.6),Color("668046"))
		Geometry.column(st,Vector3(side*1.5,3.6+side*0.5,0),1.9,0.31,0.28,Color("718a4e"),6)
	st.index()
	return st.commit()
