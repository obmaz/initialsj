extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var kind: String = str(definition.id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var bark := Color("73513a")
	Geometry.column(st,Vector3(0,5.2,0),10.4,0.3,0.18,bark)
	for tier in range(4):
		var y := 4.1+tier*1.9
		Geometry.column(st,Vector3(0,y,0),4.5-tier*0.3,3.5-tier*0.65,0,Color("326746") if tier%2 else Color("3c7952"),9)
		if kind == "snow_pine": Geometry.column(st,Vector3(0,y+0.6,0),3.2-tier*0.25,2.6-tier*0.5,0,Color("e5edf0"),9)
	st.index()
	return st.commit()
