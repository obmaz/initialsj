extends RefCounted
const Cargo = preload("res://models/shared/cargo_geometry.gd")


static func build(_definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		Cargo.container(st, Vector3((i % 2) * 2.66, (i / 2) * 2.65, 0), i)
	st.index()
	return st.commit()
