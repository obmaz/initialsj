extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")

static func build(definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	# Jeju stone guardian: porous basalt body, round head, brimmed cap, big eyes, hands on the belly.
	# Drawn larger than life so it reads from the road. Local -Z faces the road.
	var stone := Color("4f5352")
	Geometry.column(st,Vector3(0,1.3,0),2.6,0.78,0.62,stone,9)
	Geometry.round_part(st,Vector3(0,3.15,0),Vector3(1.45,1.6,1.4),stone.lightened(0.05))
	Geometry.column(st,Vector3(0,3.95,0),0.18,0.95,0.95,stone.darkened(0.1),12)
	Geometry.round_part(st,Vector3(0,4.25,0),Vector3(1.2,0.85,1.2),stone.darkened(0.05))
	for x in [-0.32,0.32]:
		Geometry.round_part(st,Vector3(x,3.35,-0.62),Vector3(0.42,0.36,0.3),stone.lightened(0.18))
		Geometry.box(st,Vector3(x*0.9,1.9,-0.62),Vector3(0.5,0.22,0.24),stone.lightened(0.12),0.4 if x < 0 else -0.4)
	Geometry.box(st,Vector3(0,3.0,-0.68),Vector3(0.36,0.6,0.32),stone.lightened(0.1))
	Geometry.column(st,Vector3(0,0.15,0),0.3,1.0,1.0,Color("3c3f3e"),9)
	st.index()
	return st.commit()
