extends RefCounted
# 코스 전용 호수·잔디. 도로와 호수 위를 같은 높이의 평면으로 덮지 않는다.
const CENTER := Vector2(-31.2, -177.45)
const HALF_SIZE := Vector2(374.4, 99.45)
const SHORE := 8.0
const BASE_HEIGHT := 6.5
const WATER_HEIGHT := 6.32
const SEGMENTS := 96


static func outline(angle: float, extra: float = 0) -> Vector2:
	var c := cos(angle)
	var s := sin(angle)
	return CENTER + Vector2(signf(c) * sqrt(absf(c)), signf(s) * sqrt(absf(s))) * (HALF_SIZE + Vector2.ONE * extra)


static func contains(point: Vector3) -> bool:
	var q := (Vector2(point.x, point.z) - CENTER).abs() / (HALF_SIZE + Vector2.ONE * SHORE)
	return pow(q.x, 4) + pow(q.y, 4) <= 1


static func quad(st: SurfaceTool, points: Array[Vector3]) -> void:
	for i in [0, 1, 2, 1, 3, 2]:
		st.set_uv(Vector2(points[i].x, points[i].z))
		st.add_vertex(points[i])


static func rectangle(st: SurfaceTool, left: float, right: float, top: float, bottom: float) -> void:
	quad(
		st,
		[
			Vector3(left, BASE_HEIGHT, top),
			Vector3(right, BASE_HEIGHT, top),
			Vector3(left, BASE_HEIGHT, bottom),
			Vector3(right, BASE_HEIGHT, bottom)
		]
	)


static func build(owner: Node3D, grass: Material) -> void:
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extents := HALF_SIZE + Vector2.ONE * SHORE
	var low := CENTER - extents
	var high := CENTER + extents
	rectangle(ground, -1200, low.x, -850, 850)
	rectangle(ground, high.x, 1200, -850, 850)
	rectangle(ground, low.x, high.x, -850, low.y)
	rectangle(ground, low.x, high.x, high.y, 850)
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shore := SurfaceTool.new()
	shore.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		var angle_a := TAU * i / SEGMENTS
		var angle_b := TAU * (i + 1) / SEGMENTS
		var a := outline(angle_a)
		var b := outline(angle_b)
		var outer_a := outline(angle_a, SHORE)
		var outer_b := outline(angle_b, SHORE)
		var da := outer_a - CENTER
		var db := outer_b - CENTER
		var rectangle_a := CENTER + da / maxf(absf(da.x / extents.x), absf(da.y / extents.y))
		var rectangle_b := CENTER + db / maxf(absf(db.x / extents.x), absf(db.y / extents.y))
		quad(
			ground,
			[
				Vector3(outer_a.x, BASE_HEIGHT, outer_a.y),
				Vector3(rectangle_a.x, BASE_HEIGHT, rectangle_a.y),
				Vector3(outer_b.x, BASE_HEIGHT, outer_b.y),
				Vector3(rectangle_b.x, BASE_HEIGHT, rectangle_b.y)
			]
		)
		quad(
			shore,
			[
				Vector3(a.x, WATER_HEIGHT - .03, a.y),
				Vector3(outer_a.x, BASE_HEIGHT, outer_a.y),
				Vector3(b.x, WATER_HEIGHT - .03, b.y),
				Vector3(outer_b.x, BASE_HEIGHT, outer_b.y)
			]
		)
		for p in [CENTER, a, b]:
			water.set_uv(p / 20)
			water.add_vertex(Vector3(p.x, WATER_HEIGHT, p.y))
	for item in [[ground, "SpeedwayInfield", grass], [shore, "LakeShore", grass]]:
		item[0].generate_normals()
		var node := MeshInstance3D.new()
		node.name = item[1]
		node.mesh = item[0].commit()
		node.material_override = item[2]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		owner.add_child(node)
	water.generate_normals()
	var lake := MeshInstance3D.new()
	lake.name = "InfieldLake"
	lake.mesh = water.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/speedway_lake.gdshader")
	material.set_shader_parameter(
		"surface_detail",
		preload("res://scripts/rendering/render_resources.gd").fetch("res://assets/environment/ocean-ripples.png")
	)
	lake.material_override = material
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(lake)
