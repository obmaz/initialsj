extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var bark := Color("73513a")
	Geometry.column(st,Vector3(0,0.9,0),1.8,0.24,0.16,bark)
	Geometry.round_part(st,Vector3(0,2.6,0),Vector3(3.2,2.6,3.2),Color("2f6e3a"))
	Geometry.round_part(st,Vector3(0.6,3.3,0.3),Vector3(2.2,1.8,2.2),Color("3a7d44"))
	for i in range(8):
		var angle := i*TAU/8
		Geometry.round_part(st,Vector3(cos(angle)*1.45,2.3+0.5*sin(i*1.3),sin(angle)*1.45),Vector3.ONE*0.38,Color("f08a1c"))
	st.index()
	return st.commit()
