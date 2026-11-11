extends RefCounted


# 차체 조립에만 쓰는 안정된 공통 API. 차량별 형상·치수를 선택하지 않는다.
static func block(car: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	car.body.add_child(n)
	n.position = pos
	return n


static func wedge(
	car: Node3D, pos: Vector3, lower: Vector2, upper: Vector2, height: float, offset: float, material: Material
) -> void:
	var vertices := PackedVector3Array(
		[
			Vector3(-lower.x / 2, 0, -lower.y / 2),
			Vector3(lower.x / 2, 0, -lower.y / 2),
			Vector3(lower.x / 2, 0, lower.y / 2),
			Vector3(-lower.x / 2, 0, lower.y / 2),
			Vector3(-upper.x / 2, height, -upper.y / 2 + offset),
			Vector3(upper.x / 2, height, -upper.y / 2 + offset),
			Vector3(upper.x / 2, height, upper.y / 2 + offset),
			Vector3(-upper.x / 2, height, upper.y / 2 + offset)
		]
	)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]:
		for index in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			st.add_vertex(vertices[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	car.body.add_child(node)
	node.position = pos


static func make_body_shell(car: Node3D, material: Material) -> void:
	var outline := [
		Vector2(-0.72, -2.2),
		Vector2(0.72, -2.2),
		Vector2(1.04, -1.55),
		Vector2(1.04, 1.55),
		Vector2(0.90, 2.2),
		Vector2(-0.90, 2.2),
		Vector2(-1.04, 1.55),
		Vector2(-1.04, -1.55)
	]
	var rings: Array[PackedVector3Array] = []
	for level in range(3):
		var ring := PackedVector3Array()
		for p: Vector2 in outline:
			var width := 0.94 if level == 0 else (1.0 if level == 1 else 0.92)
			var height := 0.36 if level == 0 else (0.65 if level == 1 else 0.87)
			ring.append(Vector3(p.x * width, height, p.y))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(2):
		for i in range(8):
			var j := (i + 1) % 8
			var points := [rings[level][i], rings[level][j], rings[level + 1][j], rings[level + 1][i]]
			for index in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(points[index])
	for i in range(8):
		for p: Vector3 in [Vector3(0, 0.87, 0), rings[2][i], rings[2][(i + 1) % 8]]:
			st.add_vertex(p)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	car.body.add_child(node)


static func beam(car: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var part: MeshInstance3D = car.block((a + b) / 2, Vector3(width, width, a.distance_to(b)), material)
	part.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)


static func label(car: Node3D, text: String, position: Vector3, color: Color, pixel_size: float) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = 40
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.position = position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.body.add_child(node)


static func arch_bottom(z: float, axle: float = 1.25, radius: float = 0.46, center_y: float = 0.39) -> float:
	var offset := minf(absf(z - axle), absf(z + axle))
	return center_y + sqrt(maxf(0, radius * radius - offset * offset)) if offset < radius else 0.22


static func make_arch_panels(
	car: Node3D,
	white: Material,
	black: Material,
	half_width: float = 0.90,
	half_length: float = 2.06,
	axle: float = 1.25,
	radius: float = 0.46,
	center_y: float = 0.39,
	upper: float = 1.0,
	split: float = 0.60
) -> void:
	for lower in [false, true]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			for i in range(100):
				var a := -half_length + i * half_length * 2 / 100
				var b := -half_length + (i + 1) * half_length * 2 / 100
				var bottom_a := arch_bottom(a, axle, radius, center_y)
				var bottom_b := arch_bottom(b, axle, radius, center_y)
				var top := split if lower else upper
				bottom_a = minf(top, bottom_a) if lower else maxf(split, bottom_a)
				bottom_b = minf(top, bottom_b) if lower else maxf(split, bottom_b)
				var points := [
					Vector3(side * half_width, bottom_a, a),
					Vector3(side * half_width, bottom_b, b),
					Vector3(side * half_width, top, a),
					Vector3(side * half_width, top, b)
				]
				for index in [0, 1, 2, 1, 3, 2] if side > 0 else [0, 2, 1, 1, 2, 3]:
					surface.set_normal(Vector3(side, 0, 0))
					surface.add_vertex(points[index])
		var panel := MeshInstance3D.new()
		panel.mesh = surface.commit()
		panel.material_override = black if lower else white
		car.body.add_child(panel)
