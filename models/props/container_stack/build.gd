extends RefCounted
const Cargo = preload("res://models/shared/cargo_geometry.gd")


static func build(_definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(3):
		for tier in range(4 if row != 1 else 3):
			Cargo.container(st, Vector3((row - 1) * 2.66, tier * 2.65, 0), (row + tier) % 3)
	st.index()
	return st.commit()
