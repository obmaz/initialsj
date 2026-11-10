extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.column(st,Vector3(0,3.3,0),6.6,0.45,0.12,Color("51463f"))
	Geometry.box(st,Vector3(0.8,4,0),Vector3(2.2,0.3,0.3),Color("51463f"),0.5)
	Geometry.box(st,Vector3(-0.8,5,0),Vector3(2,0.2,0.2),Color("51463f"),-0.5)
	st.index()
	return st.commit()
