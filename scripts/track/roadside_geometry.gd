extends RefCounted
# Continuous ribbons share their edge vertices; there are no overlapping rail boxes.
# 한 단계가 다루는 표본 수. 긴 띠를 여러 단계로 나눠 주행 중 생성이 한 프레임을 붙잡지 않게 한다.
const CHUNK := 120


# point(d,lane)는 lane에 대해 선형이다. 표본마다 중심·횡방향·폭을 한 번만 구해
# 레일·연석·차선이 같은 표를 나눠 쓴다(정점마다 곡선을 다시 표본화하지 않는다).
static func frames(section: Node3D, table: Dictionary) -> void:
	if table.is_empty():
		var empty: Array[float] = []
		table.merge(
			{
				"speedway": section.closed_loop and section.course_id == 1,
				"samples": empty,
				"origins": PackedVector3Array(),
				"laterals": PackedVector3Array(),
				"halves": PackedFloat32Array(),
				"left": PackedFloat32Array(),
				"right": PackedFloat32Array()
			}
		)
	var samples: Array[float] = table.samples
	var origins: PackedVector3Array = table.origins
	var laterals: PackedVector3Array = table.laterals
	var halves: PackedFloat32Array = table.halves
	var left: PackedFloat32Array = table.left
	var right: PackedFloat32Array = table.right
	for n in range(CHUNK):
		var d := 0.0
		if not samples.is_empty():
			var at := samples[-1]
			if at >= section.length:
				break
			var bend := absf(wrapf(section.heading(at + 2) - section.heading(at - 2), -PI, PI)) / 4
			d = minf(section.length, at + clampf(0.045 / maxf(bend, 0.0001), 0.4, 2.0))
		var origin: Vector3 = section.point(d)
		samples.append(d)
		origins.append(origin)
		laterals.append(section.point(d, 1) - origin)
		halves.append(section.half_width(d))
		left.append(section.rail_setback(d, -1.0))
		right.append(section.rail_setback(d, 1.0))
	table.origins = origins
	table.laterals = laterals
	table.halves = halves
	table.left = left
	table.right = right
	if samples[-1] < section.length:
		var more: Array[Callable] = [func(): frames(section, table)]
		section.queue_next(more)


# 단면(profile)을 도로를 따라 늘인 띠. 표본당 한 번만 정점을 만들어 이웃 구간이 색인으로 공유하고,
# 법선은 단면 방향과 진행 방향의 외적으로 직접 구한다. strands의 원소는 [방향 부호, 기준 차선, 건너뛸 구간].
static func ribbon(
	section: Node3D, table: Dictionary, profile: Array, strands: Array, with_uv: bool, finish: Callable
) -> void:
	var count: int = table.samples.size()
	var data := {
		"vertices": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"uvs": PackedVector2Array(),
		"indices": PackedInt32Array()
	}
	var steps: Array[Callable] = []
	for strand in range(strands.size()):
		for from in range(0, count, CHUNK):
			steps.append(
				func():
					ribbon_part(
						table, profile, strands[strand], strand * count, from, mini(count, from + CHUNK), with_uv, data
					)
			)
	steps.append(
		func():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = data.vertices
			arrays[Mesh.ARRAY_NORMAL] = data.normals
			if with_uv:
				arrays[Mesh.ARRAY_TEX_UV] = data.uvs
			arrays[Mesh.ARRAY_INDEX] = data.indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			finish.call(mesh)
	)
	section.queue_next(steps)


static func ribbon_part(
	table: Dictionary, profile: Array, strand: Array, first: int, from: int, to: int, with_uv: bool, data: Dictionary
) -> void:
	var side: float = strand[0]
	var base: PackedFloat32Array = strand[1]
	var skip: PackedByteArray = strand[2]
	var samples: Array[float] = table.samples
	var origins: PackedVector3Array = table.origins
	var laterals: PackedVector3Array = table.laterals
	var vertices: PackedVector3Array = data.vertices
	var normals: PackedVector3Array = data.normals
	var uvs: PackedVector2Array = data.uvs
	var indices: PackedInt32Array = data.indices
	var last := origins.size() - 1
	var rows := profile.size()
	for i in range(from, to):
		var origin := origins[i]
		var lateral := laterals[i]
		var tangent := origins[mini(i + 1, last)] - origins[maxi(i - 1, 0)]
		var ring := PackedVector3Array()
		for offset: Vector2 in profile:
			var lane: float = base[i] + offset.x * side
			var point := origin + lateral * lane + Vector3.UP * offset.y
			if table.speedway and absf(lane) > table.halves[i]:
				point.y = origin.y + lateral.y * clampf(lane, -table.halves[i], table.halves[i]) + offset.y
			ring.append(point)
		var above := Vector3.ZERO
		for k in range(rows):
			var normal := above
			if k < rows - 1:
				above = ((ring[k + 1] - ring[k]).cross(tangent) * side).normalized()
				normal += above
			vertices.append(ring[k])
			normals.append(normal.normalized())
			if with_uv:
				uvs.append(Vector2(0, samples[i]))
		if i > 0 and skip[i] == 0:
			var a := (first + i - 1) * rows
			var b := a + rows
			for k in range(rows - 1):
				if side > 0:
					indices.append_array([a + k, b + k, a + k + 1, a + k + 1, b + k, b + k + 1])
				else:
					indices.append_array([a + k, a + k + 1, b + k, a + k + 1, b + k + 1, b + k])
	data.vertices = vertices
	data.normals = normals
	data.uvs = uvs
	data.indices = indices


# 분기 진입부 150 m는 합류하는 쪽 가장자리를 비운다. skip[i]는 구간 (i-1,i)를 뜻한다.
static func edge_strand(section: Node3D, table: Dictionary, side: float, with_setback: bool, curb_rule: bool) -> Array:
	var samples: Array[float] = table.samples
	var halves: PackedFloat32Array = table.halves
	var setback: PackedFloat32Array = table.left if side < 0 else table.right
	var base := PackedFloat32Array()
	var skip := PackedByteArray()
	for i in range(samples.size()):
		base.append(side * (halves[i] + (setback[i] if with_setback else 0.0)))
		var hidden: bool = (
			(curb_rule and preload("res://scripts/track/harbor_corridor.gd").contains(section, samples[i]))
			or (section.closed_loop and section.course_id == 1 and side > 0)
			or (with_setback and side < 0 and section.speedway_pit_wall(samples[i]))
			or (
				i > 0
				and (
					(samples[i - 1] < 150 and side == -section.entry_side)
					or (curb_rule and not section.closed_loop and setback[i - 1] > 2.3)
				)
			)
		)
		skip.append(1 if hidden else 0)
	return [side, base, skip]


static func rail(section: Node3D, table: Dictionary) -> void:
	# 차도 쪽 면은 보존하고 바깥쪽으로 두께를 더한 닫힌 W형 단면.
	var profile := [
		Vector2(-0.055, 1.12),
		Vector2(0.10, 1.04),
		Vector2(-0.035, 0.93),
		Vector2(0.10, 0.83),
		Vector2(-0.055, 0.68),
		Vector2(0.26, 0.68),
		Vector2(0.26, 1.12),
		Vector2(-0.055, 1.12)
	]
	var node := MeshInstance3D.new()
	node.name = "ContinuousGuardrails"
	var steel: StandardMaterial3D = section.material(Color("9aa9af"), 0.65)
	steel.roughness = 0.38
	node.material_override = steel
	section.add_child(node)
	ribbon(
		section,
		table,
		profile,
		[edge_strand(section, table, -1.0, true, false), edge_strand(section, table, 1.0, true, false)],
		false,
		func(mesh: ArrayMesh): node.mesh = mesh
	)


static func road_mass(section: Node3D) -> void:
	# 아스팔트 아래에 두꺼운 측면을 붙여 얇은 띠처럼 보이는 가장자리를 보강한다.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil(section.length / 6))
	var node := MeshInstance3D.new()
	node.name = "SolidRoadEdges"
	node.material_override = section.material(Color("55564f"))
	section.add_child(node)
	var steps: Array[Callable] = []
	for from in range(0, count, CHUNK):
		steps.append(func(): road_mass_part(section, st, count, from, mini(count, from + CHUNK)))
	steps.append(
		func():
			st.generate_normals()
			node.mesh = st.commit()
	)
	section.queue_next(steps)


static func road_mass_part(section: Node3D, st: SurfaceTool, count: int, from: int, to: int) -> void:
	for i in range(from, to):
		var a: float = section.length * i / count
		var b: float = section.length * (i + 1) / count
		var depth := 1.8 if section.on_bridge((a + b) * 0.5) else 0.85
		for side in [-1.0, 1.0]:
			var p: Vector3 = section.point(a, side * (section.half_width(a) + 1.3)) - Vector3.UP * 0.1
			var q: Vector3 = section.point(b, side * (section.half_width(b) + 1.3)) - Vector3.UP * 0.1
			var points := [p, q, p - Vector3.UP * depth, q - Vector3.UP * depth]
			for index in [0, 2, 1, 1, 2, 3]:
				st.add_vertex(points[index])
		var width: float = section.half_width((a + b) * .5) + 1.3
		var bands: Array[Vector2] = [Vector2(-width, width)]
		if section.collapse != null and section.collapse.inside_span((a + b) * .5):
			bands = [
				Vector2(-width, section.surface_lane(section.collapse.lanes.x, (a + b) * .5)),
				Vector2(section.surface_lane(section.collapse.lanes.y, (a + b) * .5), width)
			]
		for band in bands:
			var points := [
				section.point(a, band.x), section.point(a, band.y), section.point(b, band.x), section.point(b, band.y)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				st.add_vertex(points[index] - Vector3.UP * (depth + .1))


static func shoulders(section: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := int(ceil(section.length / 5))
	var node := MeshInstance3D.new()
	node.name = "DirtShoulders"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dirt_shoulder.gdshader")
	material.set_shader_parameter("dirt_texture", load("res://assets/environment/dirt-shoulder.png"))
	material.set_shader_parameter("terrain_variants", load("res://assets/environment/terrain-variants.png"))
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	section.add_child(node)
	var steps: Array[Callable] = []
	for side in [-1.0, 1.0]:
		for from in range(0, count, CHUNK / 2):
			steps.append(func(): shoulders_part(section, st, side, count, from, mini(count, from + CHUNK / 2)))
	steps.append(
		func():
			st.generate_normals()
			node.mesh = st.commit()
	)
	section.queue_next(steps)


static func shoulders_part(section: Node3D, st: SurfaceTool, side: float, steps: int, from: int, to: int) -> void:
	for i in range(from, to):
		var a: float = section.length * i / steps
		var b: float = section.length * (i + 1) / steps
		if (
			section.closed_loop
			and section.course_id == 1
			and side > 0
			and maxf(section.rail_setback(a, side), section.rail_setback(b, side)) < .5
		):
			continue
		if a < 150 and side == -section.entry_side:
			continue
		if (
			section.in_tunnel((a + b) * 0.5)
			or section.excavation_depth((a + b) * 0.5) > 0.05
			or section.on_bridge((a + b) * 0.5)
		):
			continue
		var left: float = section.half_width(a) + 0.42
		var right: float = section.half_width(b) + 0.42
		var outer_a: float = section.half_width(a) + section.rail_setback(a, side) + 1.3
		var outer_b: float = section.half_width(b) + section.rail_setback(b, side) + 1.3
		var points := [
			section.point(a, side * left) - Vector3.UP * 0.025,
			section.point(a, side * outer_a) - Vector3.UP * 0.025,
			section.point(b, side * right) - Vector3.UP * 0.025,
			section.point(b, side * outer_b) - Vector3.UP * 0.025
		]
		for bank in range(2):
			if bank == 1:
				points = [
					points[1],
					section.scenery.terrain_point(a, side * (outer_a + section.shoulder_bank_span(a, side))),
					points[3],
					section.scenery.terrain_point(b, side * (outer_b + section.shoulder_bank_span(b, side)))
				]
			for index in [0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]:
				var grass: bool = (
					section.closed_loop
					and (bank == 1 or (section.course_id in [1, 3] and section.rail_setback(a, side) > 3))
				)
				st.set_color(Color.WHITE if grass else Color.BLACK)
				st.set_uv(Vector2(points[index].x, points[index].z) / 5)
				st.add_vertex(points[index])


static func curbs(section: Node3D, table: Dictionary) -> void:
	var profile := [Vector2(-0.25, 0.015), Vector2(-0.15, 0.13), Vector2(0.35, 0.13), Vector2(0.45, 0.015)]
	var node := MeshInstance3D.new()
	node.name = "CurvedCurbs"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/curb_paint.gdshader")
	material.set_shader_parameter("red_color", Color("c94c48"))
	material.set_shader_parameter("white_color", Color("e9e7db"))
	node.material_override = material
	section.add_child(node)
	ribbon(
		section,
		table,
		profile,
		[edge_strand(section, table, -1.0, false, true), edge_strand(section, table, 1.0, false, true)],
		true,
		func(mesh: ArrayMesh): node.mesh = mesh
	)


static func lane_marks(section: Node3D, table: Dictionary) -> void:
	var samples: Array[float] = table.samples
	var halves: PackedFloat32Array = table.halves
	var half_paint := 0.14 if section.closed_loop and section.course_id in [3, 4] else 0.055
	var strands := []
	for center in [-0.5, 0.0, 0.5]:
		var base := PackedFloat32Array()
		var skip := PackedByteArray()
		for i in range(samples.size()):
			base.append(halves[i] * center)
			skip.append(
				(
					1
					if (
						i > 0
						and (
							preload("res://scripts/track/harbor_corridor.gd").contains(section, samples[i])
							or (
								section.collapse != null
								and section.collapse.contains((samples[i - 1] + samples[i]) * 0.5, center * 9)
							)
						)
					)
					else 0
				)
			)
		strands.append([1.0, base, skip])
	var paint := MeshInstance3D.new()
	paint.name = "CurvedLaneMarks"
	var lane_material := ShaderMaterial.new()
	lane_material.shader = preload("res://shaders/lane_dash.gdshader")
	if section.closed_loop and section.course_id in [3, 4]:
		lane_material.set_shader_parameter("dash_length", 6.0)
		lane_material.set_shader_parameter("dash_period", 14.0)
		lane_material.set_shader_parameter("paint_color", Color("f9f6df"))
	paint.material_override = lane_material
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	section.add_child(paint)
	ribbon(
		section,
		table,
		[Vector2(-half_paint, 0.027), Vector2(half_paint, 0.027)],
		strands,
		true,
		func(mesh: ArrayMesh): paint.mesh = mesh
	)
