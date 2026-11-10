extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for x in [-3.0,3.0]: Geometry.column(st,Vector3(x,5,0),10,0.42,0.36,Color("6f777c"),6)
	Geometry.box(st,Vector3(0,10.4,0),Vector3(10.5,5.2,0.9),Color("33383d"))
	Geometry.box(st,Vector3(0,10.4,0.48),Vector3(10,4.7,0.1),Color("f3f0e4"),0,20)
	# 기초·뒤쪽 가로보·입체 테두리는 광고 이미지와 별개인 실제 구조물이다.
	for x in [-3.0,3.0]: Geometry.box(st,Vector3(x,.15,0),Vector3(1.4,.7,1.4),Color("92918a"))
	for y in [8.0,12.8]: Geometry.box(st,Vector3(0,y,.48),Vector3(10.6,.28,.32),Color("56616a"))
	for x in [-5.15,5.15]: Geometry.box(st,Vector3(x,10.4,.48),Vector3(.28,5.2,.32),Color("56616a"))
	for y in [8.8,11.8]: Geometry.box(st,Vector3(0,y,-.62),Vector3(7.0,.24,.32),Color("4e575d"))
	st.index()
	return st.commit()
