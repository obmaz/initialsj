extends RefCounted
# 40피트 화물 컨테이너. 면별 UV와 실제 철판 골·모서리 프레임을 함께 만든다.
const Geometry = preload("res://models/shared/prop_geometry.gd")
const SIZE := Vector3(2.44, 2.59, 12.19)


static func container(st: SurfaceTool, center: Vector3, brand: int) -> void:
	for side in [-1.0, 1.0]:
		for step in range(36):
			var a := float(step) / 36
			var b := float(step + 1) / 36
			var xa: float = side * (SIZE.x * .5 - (.055 if step % 3 == 1 else 0.0))
			var xb: float = side * (SIZE.x * .5 - (.055 if (step + 1) % 3 == 1 else 0.0))
			var points := [
				Vector3(xa, 0, (a - .5) * SIZE.z),
				Vector3(xb, 0, (b - .5) * SIZE.z),
				Vector3(xa, SIZE.y, (a - .5) * SIZE.z),
				Vector3(xb, SIZE.y, (b - .5) * SIZE.z)
			]
			var uv := [
				Vector2(a if side < 0 else 1 - a, 1),
				Vector2(b if side < 0 else 1 - b, 1),
				Vector2(a if side < 0 else 1 - a, 0),
				Vector2(b if side < 0 else 1 - b, 0)
			]
			quad(st, center, points, uv, brand, 0, side < 0)
		var z: float = side * SIZE.z * .5
		quad(
			st,
			center,
			[
				Vector3(-SIZE.x * .5, 0, z),
				Vector3(SIZE.x * .5, 0, z),
				Vector3(-SIZE.x * .5, SIZE.y, z),
				Vector3(SIZE.x * .5, SIZE.y, z)
			],
			[
				Vector2(1 if side < 0 else 0, 1),
				Vector2(0 if side < 0 else 1, 1),
				Vector2(1 if side < 0 else 0, 0),
				Vector2(0 if side < 0 else 1, 0)
			],
			brand,
			1,
			side > 0
		)
		var y := SIZE.y if side > 0 else 0.0
		quad(
			st,
			center,
			[
				Vector3(-SIZE.x * .5, y, -SIZE.z * .5),
				Vector3(SIZE.x * .5, y, -SIZE.z * .5),
				Vector3(-SIZE.x * .5, y, SIZE.z * .5),
				Vector3(SIZE.x * .5, y, SIZE.z * .5)
			],
			[Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE],
			brand,
			2,
			side < 0
		)
	var trim: Color = [Color("79443b"), Color("263c4f"), Color("a9a68f")][brand % 3]
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			Geometry.box(
				st,
				center + Vector3(side * (SIZE.x * .5 - .055), SIZE.y * .5, end * (SIZE.z * .5 - .055)),
				Vector3(.16, SIZE.y, .16),
				trim
			)
		for y in [.07, SIZE.y - .07]:
			Geometry.box(st, center + Vector3(side * (SIZE.x * .5 - .04), y, 0), Vector3(.14, .14, SIZE.z), trim)


static func quad(
	st: SurfaceTool, center: Vector3, points: Array, uv: Array, brand: int, face: int, reverse: bool
) -> void:
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	if reverse:
		normal = -normal
	for i in [0, 2, 1, 1, 2, 3] if reverse else [0, 1, 2, 1, 3, 2]:
		st.set_color(Color.WHITE)
		st.set_uv(uv[i])
		st.set_uv2(Vector2(brand + 1, face + 1))
		st.set_normal(normal)
		st.add_vertex(center + points[i])
