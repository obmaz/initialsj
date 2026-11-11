extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for i in range(3):
		var p := Vector3((i - 1) * 3, 0, 0)
		Geometry.box(st, p + Vector3.UP * 0.3, Vector3(2.5, 0.6, 2.5), Color("918d7e"))
		Geometry.column(st, p + Vector3.UP * (2 + i * 0.8), 3.7 + i * 1.6, 0.8, 0.8, Color("9d9989"), 8)
	Geometry.box(st, Vector3(1.5, 6.5, 0), Vector3(6.5, 0.8, 1.9), Color("8b8679"), 0.05)
	st.index()
	return st.commit()
