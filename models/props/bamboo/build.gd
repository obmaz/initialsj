extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var green := Color("367a48")
	for stalk in range(5):
		var p := Vector3(cos(stalk*2.4)*1.25,0,sin(stalk*2.4)*1.25)
		var height := 7.0+(stalk%3)*1.5
		Geometry.column(st,p+Vector3.UP*height*0.5,height,0.12,0.09,Color("67984c"),6)
		for ring in range(1,int(height)):
			Geometry.column(st,p+Vector3.UP*ring,0.06,0.14,0.14,Color("aec477"),6)
		for branch in range(3):
			var angle := stalk*2.1+branch*1.8
			Geometry.round_part(st,p+Vector3(cos(angle)*0.8,height-branch*1.3,sin(angle)*0.8),Vector3(2.4,0.5,1.1),green)
	st.index()
	return st.commit()
