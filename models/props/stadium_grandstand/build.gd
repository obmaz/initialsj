extends RefCounted
const Geometry = preload("res://models/shared/prop_geometry.gd")


static func build(_definition: Resource) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	st.set_uv2(Vector2.ZERO)
	for row in range(64):
		var promenade: int = row / 22
		var z: float = -row * .98 - promenade * 2.4
		var top := .8 + row * .62 + promenade * 1.4
		Geometry.box(st, Vector3(0, top * .5, z), Vector3(74, top, 1.02), Color("8b9397"))
		if row % 22 == 21:
			continue
		for block in range(3):
			var left := -36.0 + block * 24
			var points := [
				Vector3(left, top + .025, z + .44),
				Vector3(left + 22, top + .025, z + .44),
				Vector3(left, top + .025, z - .44),
				Vector3(left + 22, top + .025, z - .44)
			]
			for index in [0, 2, 1, 1, 2, 3]:
				var p: Vector3 = points[index]
				st.set_normal(Vector3.UP)
				st.set_color(Color.WHITE)
				st.set_uv2(Vector2.ONE)
				st.set_uv(Vector2((p.x + 36) / 22, (row + (.44 + z - p.z) / .88) / 32.0))
				st.add_vertex(p)
			# 낮은 운전자 시점에서도 관중의 머리·상체를 볼 수 있는 좌석 정면.
			var fronts := [
				Vector3(left, top - .55, z + .525),
				Vector3(left + 22, top - .55, z + .525),
				Vector3(left, top + .08, z + .525),
				Vector3(left + 22, top + .08, z + .525)
			]
			for index in [0, 2, 1, 1, 2, 3]:
				var p: Vector3 = fronts[index]
				st.set_normal(Vector3.BACK)
				st.set_color(Color.WHITE)
				st.set_uv2(Vector2.ONE)
				st.set_uv(Vector2((p.x + 36) / 22, (row + (top + .08 - p.y) / .63) / 32.0))
				st.add_vertex(p)
	Geometry.box(st, Vector3(0, 46, -64.5), Vector3(74, 5, 9), Color("596773"))
	Geometry.box(st, Vector3(0, 48, -59.8), Vector3(72, 1.6, .15), Color("293b49"))
	Geometry.box(st, Vector3(0, 51, -62), Vector3(76, .7, 16), Color("d4d9db"))
	for x in [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]:
		Geometry.box(st, Vector3(x, 24.5, -68), Vector3(.55, 49, .55), Color("637078"))
	for row in [0, 22, 44, 63]:
		var z: float = -row * .98 - (row / 22) * 2.4 + .7
		var y: float = .8 + row * .62 + (row / 22) * 1.4 + 1.1
		Geometry.box(st, Vector3(0, y, z), Vector3(74, .10, .12), Color("ced4d8"))
		for x in [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]:
			Geometry.box(st, Vector3(x, y - .55, z), Vector3(.09, 1.1, .09), Color("89959d"))
	st.index()
	var source := st.commit()
	var arrays := source.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		if tags[i].x > .5:
			continue
		var concrete := colors[i].is_equal_approx(Color("8b9397"))
		var operations := colors[i].is_equal_approx(Color("596773")) or colors[i].is_equal_approx(Color("293b49"))
		if not concrete and not operations:
			continue
		var p := vertices[i]
		uvs[i] = (
			Vector2(p.z, -p.y) / 8
			if absf(normals[i].x) > .5
			else Vector2(p.x, p.z if absf(normals[i].y) > .5 else -p.y) / 8
		)
		tags[i].x = 2 if operations else 3
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = tags
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
