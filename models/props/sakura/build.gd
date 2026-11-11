extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var kind: String = str(definition.id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var bark := Color("73513a")
	var green := Color("367a48")
	Geometry.column(st, Vector3(0, 3.2, 0), 6.4, 0.38, 0.22, bark)
	var crown_color := Color("edacc5") if kind == "sakura" else (Color("b8ac42") if kind == "ginkgo" else green)
	var top := 7.0 if kind == "sakura" else (9.0 if kind == "plane_tree" else 8.0)
	for i in range(5):
		var angle := i * TAU / 5
		var p := Vector3(cos(angle) * 1.6, top + 0.4 * sin(angle * 2), sin(angle) * 1.6)
		Geometry.round_part(
			st,
			p,
			Vector3(
				3.8 if kind == "plane_tree" else 4.7,
				3.4 if kind == "sakura" else (5.5 if kind == "plane_tree" else 4.5),
				3.8 if kind == "plane_tree" else 4.7
			),
			crown_color.lightened((i % 3) * 0.06)
		)
	Geometry.round_part(st, Vector3(0, top + 1.6, 0), Vector3(4.5, 4, 4.5), crown_color)
	st.index()
	return st.commit()
