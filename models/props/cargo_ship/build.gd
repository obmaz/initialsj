extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st,Vector3(0,3.2,0),Vector3(18,6.4,86),Color("2d3e57"))
	Geometry.box(st,Vector3(0,6.7,0),Vector3(18.4,0.5,86.4),Color("a8362b"))
	Geometry.box(st,Vector3(0,3.5,-43.5),Vector3(10,6,2.5),Color("2d3e57"))
	Geometry.box(st,Vector3(0,12,34),Vector3(12,11,10),Color("e9e9e2"))
	Geometry.box(st,Vector3(0,18.2,34),Vector3(13,2,10.5),Color("2c4a66"))
	Geometry.box(st,Vector3(0,22.5,34),Vector3(3,7,3),Color("c4472f"))
	var paints2 := [Color("a45540"),Color("466f7f"),Color("c49c4f"),Color("2f7a62"),Color("c9553f"),Color("8a8f93")]
	for row in range(3):
		for bay in range(7):
			for tier in range(1+(row+bay)%3):
				Geometry.box(st,Vector3(row*5.4-5.4,8.2+tier*2.65,-34+bay*8.4),Vector3(5.1,2.55,8.1),paints2[(row*3+bay+tier)%paints2.size()],0,50+(row+bay+tier)%4)
	st.index()
	return st.commit()
