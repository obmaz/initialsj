extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	Geometry.box(st, Vector3(0, 1.8, 0), Vector3(10, 3.6, 6.4), Color("e8ebec"), 0, 1)
	Geometry.box(st, Vector3(0, 3.85, 0), Vector3(10.4, 0.55, 6.8), Color("2fa36b"))
	Geometry.box(st, Vector3(0, 3.45, 0), Vector3(10.45, 0.12, 6.85), Color("f08a1c"))
	Geometry.box(st, Vector3(0, 3.0, 3.3), Vector3(8, 0.5, 0.2), Color("fff1a8"))
	Geometry.box(st, Vector3(2, 5.2, -1.6), Vector3(2.4, 1.8, 1.6), Color("8b9296"))
	Geometry.box(st, Vector3(-3.4, 4.8, 3.0), Vector3(2.8, 1.5, 0.2), Color("ffd34a"))
	Geometry.box(st, Vector3(0, 0.1, 1.5), Vector3(12, 0.2, 11), Color("6c7176"))
	# 최종 실척: 주차 간격 2.72m, 스토퍼 1.7×0.14×0.22m. 전정 상면에 놓는다.
	for x in [-3.4, -1.7, 0.0, 1.7, 3.4]:
		Geometry.box(st, Vector3(x, .2583, 4.4), Vector3(1.0625, .1167, .1333), Color("d9d9d4"))
	Geometry.architectural_mass(
		st,
		definition.base_size,
		definition.parameters.mass_offset,
		definition.parameters.floors,
		definition.parameters.columns
	)
	st.index()
	return st.commit()
