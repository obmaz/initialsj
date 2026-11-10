extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	# A dry-stacked black basalt field wall.
	for i in range(9):
		var x := -5.6+i*1.4
		Geometry.round_part(st,Vector3(x,0.45,sin(i*1.7)*0.12),Vector3(1.5,0.95,1.0),Color("2f3333").lightened((i%3)*0.06))
		Geometry.round_part(st,Vector3(x+0.7,1.15,sin(i*2.3)*0.1),Vector3(1.3,0.75,0.9),Color("383d3c").lightened((i%2)*0.05))
	st.index()
	return st.commit()
