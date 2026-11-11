extends Node3D
# 도로 형상을 따르는 정글의 덩굴·흙덮개·두꺼운 암석 터널 입구.
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Library = preload("res://scripts/track/route_library.gd")
const ROCK = "res://assets/environment/jungle-moss-stone.png"
var scenery: Node3D
var road: Node3D
var material: ShaderMaterial
var vine_count := 0
var roof_sections := 0
var hanging_clearance := INF


func _ready() -> void:
	road = scenery.track
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/jungle_tunnel.gdshader")
	material.set_shader_parameter("rock_detail", preload("res://scripts/rendering/render_resources.gd").fetch(ROCK))
	var steps: Array[Callable] = [func(): Props.warm("jungle_vine")]
	for begin in range(90, int(road.length - 180), 84):
		steps.append(func(): growth_range(begin, minf(begin + 84, road.length - 180)))
	var tunnel := Library.tunnel_span(road.stage, road.route_node)
	for begin in range(int(tunnel.x), int(tunnel.y), 64):
		steps.append(func(): roof_part(begin, minf(begin + 64, tunnel.y)))
	steps.append(func(): portal(tunnel.x, "JungleEntrance"))
	steps.append(func(): portal(tunnel.y, "JungleExit"))
	steps.append(func(): Props.release_warm("jungle_vine"))
	road.queue_next(steps)


func growth_range(begin: float, end: float) -> void:
	var placements: Array[Dictionary] = []
	var d := begin
	while d < end:
		var tunnel: bool = road.in_tunnel(d)
		for side in [-1.0, 1.0]:
			if not tunnel and road.entry_side != 0 and d < 240 and side != road.entry_side:
				continue
			var lane: float = (
				side * (road.half_width(d) * .65 if tunnel else road.half_width(d) + road.rail_setback(d, side) + 11)
			)
			var p: Vector3 = road.point(d, lane) + Vector3.UP * 5.3 if tunnel else scenery.terrain_point(d, lane)
			var scale := .28 if tunnel else .85 + .15 * sin(d * .12 + side)
			placements.append(
				{"kind": "jungle_vine", "position": p, "yaw": road.heading(d) + d * .11 + side, "scale": scale}
			)
			vine_count += 1
			if tunnel:
				hanging_clearance = minf(
					hanging_clearance, 5.3 + Props.model("jungle_vine").get_aabb().position.y * scale
				)
		d += 14
	var props := Props.new()
	props.configure("jungle", placements)
	add_child(props)


func roof_point(d: float, u: float) -> Vector3:
	var width: float = road.half_width(d) + 23
	var left: Vector3 = scenery.terrain_point(d, -width)
	var right: Vector3 = scenery.terrain_point(d, width)
	var p: Vector3 = road.point(d, lerpf(-width, width, u))
	p.y = maxf(p.y + 10, lerpf(left.y, right.y, u) + 7 * sin(PI * u))
	return p


func mesh_node(st: SurfaceTool, label: String, origin: Vector3) -> void:
	st.index()
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.position = origin
	mesh.mesh = st.commit()
	mesh.material_override = material
	mesh.visibility_range_end = 500
	add_child(mesh)


func roof_part(begin: float, end: float) -> void:
	var origin: Vector3 = road.point(begin)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := ceili((end - begin) / 8)
	for i in range(count):
		for across in range(8):
			for index in [0, 2, 1, 1, 2, 3]:
				var d := lerpf(begin, end, float(i + (index / 2)) / count)
				var u := float(across + index % 2) / 8
				st.set_uv(Vector2(u * 14, d / 5))
				st.add_vertex(roof_point(d, u) - origin)
	mesh_node(st, "JungleTunnelRoof", origin)
	var canopy := preload("res://scripts/environment/tour_vegetation.gd").new()
	canopy.name = "TunnelCanopy"
	for at in [begin + 12, minf(begin + 44, end - 4)]:
		for u in [.25, .75]:
			canopy.plantings.append(
				{"variant": int(at + u * 10) % 2, "position": roof_point(at, u), "yaw": at * .07 + u, "scale": .9}
			)
	add_child(canopy)
	roof_sections += 1


func portal(d: float, label: String) -> void:
	var origin: Vector3 = road.point(d)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width: float = road.half_width(d) + 2.4
	var top: float = maxf(18, road.jungle_cut_depth(d) + 8)
	for part in range(18):
		for face in range(4):
			for index in [0, 1, 2, 1, 3, 2]:
				var edge: int = index % 2
				var span: int = index / 2
				var inner: bool = (edge == 0) if face < 2 else (face == 2)
				var at: float = d + ((-1.6 if face == 0 else 1.6) if face < 2 else (-1.6 if edge == 0 else 1.6))
				var angle := PI * clampf(float(part + span - 1) / 16, 0, 1)
				var lane := -cos(angle) * (width if inner else width + 16)
				var height := (3.2 + 5 * sin(angle)) if inner else (4 + top * sin(angle))
				if part + span == 0 or part + span == 18:
					height = 0
				st.set_uv(Vector2(lane / 4, height / 4 + at / 6))
				st.add_vertex(road.point(at, lane) + Vector3.UP * height - origin)
	mesh_node(st, label, origin)
	var vines: Array[Dictionary] = []
	for row in range(3):
		for side in [-1.0, 1.0]:
			vines.append(
				{
					"kind": "jungle_vine",
					"position":
					(
						road.point(d + (-2.0 if label == "JungleEntrance" else 2.0), side * (width + 4))
						+ Vector3.UP * row * 9.5
					),
					"yaw": road.heading(d),
					"scale": 1.0
				}
			)
	var fringe := Props.new()
	fringe.name = label + "Vines"
	fringe.configure("jungle", vines)
	add_child(fringe)
