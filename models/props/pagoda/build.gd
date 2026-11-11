extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 0.4, 0), Vector3(7, 0.8, 7), Color("7b8077"))
	for tier in range(3):
		var w := 6.0 - tier * 1.2
		var y := 1.8 + tier * 2.5
		Geometry.box(st, Vector3(0, y, 0), Vector3(w * 0.7, 2, w * 0.7), Color("c0a17a"), 0, 10)
		Geometry.box(st, Vector3(0, y, 0), Vector3(w * 0.78, 0.5, w * 0.78), Color("944637"))
		Geometry.column(st, Vector3(0, y + 1.5, 0), 1.4, w * 0.8, w * 0.22, Color("405754"), 4)
	Geometry.column(st, Vector3(0, 9.7, 0), 2.0, 0.15, 0.05, Color("cfb76c"))
	st.index()
	return st.commit()
