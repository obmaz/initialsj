extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var kind: String = str(definition.id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for i in range(4):
		var height := 1.4+(i%3)*0.8
		Geometry.round_part(st,Vector3(cos(i*2.1)*1.8,height*0.45,sin(i*2.1)*1.8),Vector3(3,height,3.5),Color("394649") if kind == "basalt" else Color("ba8156"))
	st.index()
	return st.commit()
