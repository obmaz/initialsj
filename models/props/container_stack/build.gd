extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	var paints := [Color("a45540"), Color("466f7f"), Color("c49c4f"), Color("2f7a62"), Color("8a8f93"), Color("c9553f")]
	for row in range(3):
		for tier in range(4 if row != 1 else 3):
			var paint: Color = paints[(row * 2 + tier * 3) % paints.size()]
			Geometry.box(
				st,
				Vector3(row * 2.7 - 2.7, 1.3 + tier * 2.65, 0),
				Vector3(2.5, 2.55, 12),
				paint,
				0,
				50 + (row + tier) % 4
			)
			for rib in range(6):
				Geometry.box(
					st,
					Vector3(row * 2.7 - 2.7, 1.3 + tier * 2.65, -5.4 + rib * 2.15),
					Vector3(2.55, 2.4, 0.1),
					paint.darkened(0.25)
				)
	st.index()
	return st.commit()
