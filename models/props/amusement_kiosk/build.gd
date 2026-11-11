extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(_definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	Geometry.box(st, Vector3(0, 2.2, 0), Vector3(8, 4, 6.5), Color.WHITE, 0, 8)
	Geometry.box(st, Vector3(0, .125, 0), Vector3(8.8, .25, 8), Color("898d86"))
	Geometry.box(st, Vector3(0, 4.45, 0), Vector3(8.8, .5, 7.4), Color("994d56"))
	Geometry.box(st, Vector3(0, 3.8, 3.7), Vector3(8.6, .18, 1.6), Color("e6d8b7"))
	for x in [-3.9, 3.9]:
		Geometry.box(st, Vector3(x, 1.95, 4.2), Vector3(.18, 3.6, .18), Color("b9b29b"))
	Geometry.box(st, Vector3(0, 1.05, 3.35), Vector3(7.6, .2, .5), Color("b7a68a"))
	Geometry.box(st, Vector3(0, 4.95, -1.5), Vector3(1.4, .5, 1), Color("777e7c"))
	st.index()
	return st.commit()
