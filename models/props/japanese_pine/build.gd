extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var bark := Color("73513a")
	Geometry.column(st, Vector3(0, 3.7, 0), 7.4, 0.4, 0.16, bark)
	for i in range(5):
		var angle := i * 2.4
		var p := Vector3(cos(angle) * 1.9, 5.7 + i * 0.65, sin(angle) * 1.9)
		Geometry.box(st, Vector3(p.x * 0.5, p.y - 0.6, p.z * 0.5), Vector3(3.6, 0.2, 0.25), bark, angle)
		Geometry.round_part(st, p, Vector3(4.8, 1.6, 3.8), Color("3b6e4f").lightened((i % 3) * 0.05))
	st.index()
	return st.commit()
