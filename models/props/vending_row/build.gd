extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var cols := [Color("d6342b"),Color("2c5fa6"),Color("2f8a5a"),Color("e0a030")]
	for i in range(4):
		Geometry.box(st,Vector3(-2.4+i*1.6,1.1,0),Vector3(1.2,2.2,0.9),cols[i])
		Geometry.box(st,Vector3(-2.4+i*1.6,1.3,0.47),Vector3(0.9,1.3,0.05),Color("f4f6f2"))
	Geometry.box(st,Vector3(0,2.5,0.1),Vector3(7.4,0.2,2.0),Color("5b5148"))
	Geometry.box(st,Vector3(0,0.06,0.4),Vector3(7.6,0.12,2.6),Color("858c87"))
	st.index()
	return st.commit()
