extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,2,0),Vector3(13,0.6,4),Color("9d4d3e"))
	for x in [-5.5,-2.8,0.0,2.8,5.5]:
		for side in [-1,1]: Geometry.box(st,Vector3(x,2.8,side*1.8),Vector3(0.25,1.8,0.25),Color("c95e43"))
		Geometry.box(st,Vector3(x,0.9,0),Vector3(0.7,1.8,3.5),Color("747d70"))
	for side in [-1,1]: Geometry.box(st,Vector3(0,3.4,side*1.8),Vector3(13,0.25,0.3),Color("c95e43"))
	st.index()
	return st.commit()
