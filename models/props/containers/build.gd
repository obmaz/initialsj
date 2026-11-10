extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for i in range(3):
		Geometry.box(st,Vector3((i%2)*3.3,1.5+(i/2)*3.1,0),Vector3(3.1,3,8),Color(["a45540","466f7f","c49c4f"][i]),0,50+i)
		for rib in range(8): Geometry.box(st,Vector3((i%2)*3.3+1.58,1.5+(i/2)*3.1,-3.5+rib),Vector3(0.08,2.8,0.1),Color("73867e"))
	st.index()
	return st.commit()
