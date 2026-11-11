extends Node3D
# MIDNIGHT HARBOR scenery: a dark container yard with lit warehouses, cranes, street lamps with
# light pools on the road, neon drift gates and a star sky. All real 3D boxes in a handful of
# MultiMesh batches (no per-lamp lights), so it stays cheap on phones.
const GROUND_Y := 3.3
const EDGE_EXTRA := 1.3
var theme := "night"
var track: Node3D
var tree_positions: Array[Vector3] = []
var batches: Array[MultiMeshInstance3D] = []
var rng := RandomNumberGenerator.new()
var drift_gates: Array[float] = []


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/harbor-panorama.png"
	)


func set_ground_enabled(_enabled: bool) -> void:
	pass


# Dark yard around the road: it follows the road height near the edge and falls to the harbour
# ground level within about 30 m, so the road reads as raised on a low embankment.
func terrain_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(distance, lane)
	var road_y: float = track.ground_height(distance) - 0.25
	var edge: float = track.half_width(distance) + track.rail_setback(distance, signf(lane)) + EDGE_EXTRA
	p.y = lerpf(road_y, GROUND_Y, smoothstep(0.0, 30.0, absf(lane) - edge))
	return p


func _ready() -> void:
	rng.seed = 5252
	make_ground()
	find_drift_gates()
	make_yard()
	make_warehouses()
	make_cranes()
	make_harbor_props()
	make_lamps()
	make_gates()


func clear_of_road(d: float, lane: float, margin: float) -> bool:
	# Props stay away from every other stretch of the circuit, not just their own.
	var p: Vector3 = track.point(d, lane)
	var near: float = track.curve.get_closest_offset(p)
	var q: Vector3 = track.point(near)
	var reach: float = track.half_width(near) + track.rail_setback(near, 1.0) + margin
	return Vector2(p.x - q.x, p.z - q.z).length() >= reach


func make_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(ceil(track.length / 8))
	var offsets := [0.0, 4.0, 9.0, 16.0, 24.0, 32.0]
	for side in [-1.0, 1.0]:
		for i in range(steps):
			var a: float = track.length * i / steps
			var b: float = track.length * (i + 1) / steps
			for band in range(offsets.size() - 1):
				var edge_a: float = track.half_width(a) + track.rail_setback(a, side) + EDGE_EXTRA
				var edge_b: float = track.half_width(b) + track.rail_setback(b, side) + EDGE_EXTRA
				var points := [
					terrain_point(a, side * (edge_a + offsets[band])),
					terrain_point(a, side * (edge_a + offsets[band + 1])),
					terrain_point(b, side * (edge_b + offsets[band])),
					terrain_point(b, side * (edge_b + offsets[band + 1]))
				]
				var order := [0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]
				for index in order:
					st.add_vertex(points[index])
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("141a20")
	material.roughness = 0.97
	var node := MeshInstance3D.new()
	node.name = "HarbourYard"
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


# Distances where a tight bend begins: a neon DRIFT gate stands over the road before each.
func find_drift_gates() -> void:
	var d := 40.0
	var last := -1000.0
	while d < track.length - 40:
		if absf(track.curvature(d + 30)) > 0.0125 and d - last > 140:
			drift_gates.append(d - 35)
			last = d
		d += 6.0


func batch(label: String, size: Vector3, material: Material, poses: Array[Transform3D]) -> void:
	if poses.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for i in range(poses.size()):
		instances.set_instance_transform(i, poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches.append(node)


func lit(color: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = glow
	return m


func pose(d: float, lane: float, height: float, yaw: float = 0.0) -> Transform3D:
	var p: Vector3 = terrain_point(d, lane)
	return Transform3D(Basis(Vector3.UP, track.heading(d) + yaw), p + Vector3.UP * height)


func make_yard() -> void:
	var colours := [Color("8a3b2c"), Color("2f5f86"), Color("2d7a62"), Color("a77a2c")]
	var stacks: Array = []
	for index in range(colours.size()):
		var empty: Array[Transform3D] = []
		stacks.append(empty)
	var count := int(track.length / 34)
	for i in range(count):
		var d: float = 70 + i * (track.length - 140) / count + rng.randf_range(-6, 6)
		var side := -1.0 if i % 2 == 0 else 1.0
		var edge: float = track.half_width(d) + track.rail_setback(d, side)
		var lane: float = side * (edge + rng.randf_range(11, 22))
		if not clear_of_road(d, lane, 9.0):
			continue
		var tiers := 1 + rng.randi() % 3
		var colour_index := rng.randi() % colours.size()
		for tier in range(tiers):
			stacks[(colour_index + tier) % colours.size()].append(
				pose(d, lane, 1.25 + tier * 2.5, rng.randf_range(-0.05, 0.05))
			)
	for index in range(colours.size()):
		var skin := ShaderMaterial.new()
		skin.shader = preload("res://shaders/container_skin.gdshader")
		skin.set_shader_parameter("skins", load("res://assets/environment/container-elevations.png"))
		skin.set_shader_parameter("brand", index)
		batch("Containers" + str(index), Vector3(12, 2.45, 2.6), skin, stacks[index])


func make_warehouses() -> void:
	var poses: Array[Transform3D] = []
	var sizes: Array[Color] = []
	var count := int(track.length / 110)
	for i in range(count):
		var d: float = 120 + i * (track.length - 240) / count
		var side := -1.0 if i % 2 == 1 else 1.0
		var width := rng.randf_range(36, 58)
		var depth := rng.randf_range(26, 38)
		var height := rng.randf_range(12, 21)
		if not preload("res://scripts/environment/settlement_layout.gd").allows(
			track, d, Vector2(width, depth).length() * .5
		):
			continue
		var lane: float = side * (track.half_width(d) + track.rail_setback(d, side) + 34 + depth * 0.5)
		if not clear_of_road(d, lane, depth * 0.8 + 10):
			continue
		var base := pose(d, lane, height * 0.5)
		poses.append(base.scaled_local(Vector3(width, height, depth)))
		sizes.append(Color(width, height, depth, rng.randf()))
	if poses.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	multi.mesh = cube
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i, poses[i])
		multi.set_instance_custom_data(i, sizes[i])
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/building_facade.gdshader")
	material.set_shader_parameter("facade_images", load("res://assets/environment/urban-harbor-facades.png"))
	material.set_shader_parameter("night_city", true)
	material.set_shader_parameter("industrial_facade", true)
	material.set_shader_parameter("facade_style", 0)
	var node := MultiMeshInstance3D.new()
	node.name = "Warehouses"
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches.append(node)


# Big harbour furniture from the shared prop set: stacked cargo, dock cranes, fuel tanks, sheds and
# docked container ships, set back from the road so every bend has something large beside it.
func make_harbor_props() -> void:
	var Props = preload("res://scripts/environment/regional_props_3d.gd")
	var kinds := [
		"container_stack",
		"dock_crane",
		"container_stack",
		"warehouse_shed",
		"fuel_tank",
		"container_stack",
		"cargo_ship",
		"container_stack"
	]
	var placements: Array[Dictionary] = []
	var spacing := 70.0
	var count := int(track.length / spacing)
	for i in range(count):
		var d: float = 60 + i * spacing + rng.randf_range(-8, 8)
		var side := -1.0 if i % 2 == 0 else 1.0
		var kind: String = kinds[i % kinds.size()]
		var scale := rng.randf_range(0.95, 1.2)
		var radius: float = Props.radius(kind) * scale
		var extra := 8.0 if kind in ["container_stack", "fuel_tank"] else (30.0 if kind == "cargo_ship" else 16.0)
		var lane: float = side * (track.half_width(d) + track.rail_setback(d, side) + extra + radius)
		if not clear_of_road(d, lane, radius * 0.9 + 4.0):
			continue
		var base := pose(d, lane, 0.0, PI * 0.5 if kind in ["container_stack", "cargo_ship", "warehouse_shed"] else 0.0)
		placements.append(
			{
				"position": base.origin,
				"yaw": track.heading(d) + (PI * 0.5 if kind == "cargo_ship" else rng.randf_range(-0.15, 0.15)),
				"scale": scale,
				"kind": kind
			}
		)
	var props = Props.new()
	props.name = "HarbourProps"
	props.configure("harbor", placements)
	add_child(props)


# Gantry cranes along the quay, each with a red beacon on top.
func make_cranes() -> void:
	var frames: Array[Transform3D] = []
	var beams: Array[Transform3D] = []
	var beacons: Array[Transform3D] = []
	for d in [260.0, 560.0, 1500.0, 1750.0, 2450.0]:
		var side := 1.0 if int(d / 10) % 2 == 0 else -1.0
		var lane: float = side * (track.half_width(d) + track.rail_setback(d, side) + 52)
		if not clear_of_road(d, lane, 28.0):
			continue
		var base := pose(d, lane, 0.0)
		for leg in [-9.0, 9.0]:
			frames.append(base.translated_local(Vector3(leg, 19, 0)))
		beams.append(base.translated_local(Vector3(0, 38, 0)))
		beacons.append(base.translated_local(Vector3(0, 41, 0)))
	var steel := lit(Color("39434d"), 0.1)
	batch("CraneLegs", Vector3(1.6, 38, 1.6), steel, frames)
	batch("CraneBeams", Vector3(34, 2.4, 2.4), steel, beams)
	batch("CraneBeacons", Vector3(1.4, 1.4, 1.4), lit(Color("ff3b30"), 3.0), beacons)


func make_lamps() -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var pools: Array[Transform3D] = []
	var spacing := 38.0
	var count := int(track.length / spacing)
	for i in range(count):
		var d := 20.0 + i * spacing
		var side := -1.0 if i % 2 == 0 else 1.0
		var edge: float = track.half_width(d) + track.rail_setback(d, side)
		var base := pose(d, side * (edge + 1.9), 0.0)
		poles.append(base.translated_local(Vector3(0, 4.3, 0)))
		heads.append(base.translated_local(Vector3(-side * 0.9, 8.7, 0)))
		# A soft pool of light on the asphalt under the lamp.
		var ground: Vector3 = track.point(d, side * track.half_width(d) * 0.35)
		var flat := Transform3D(
			Basis(Vector3.UP, track.heading(d)) * Basis(Vector3.RIGHT, -PI * 0.5), ground + Vector3.UP * 0.09
		)
		pools.append(flat.scaled_local(Vector3(15, 15, 1)))
	batch("LampPoles", Vector3(0.22, 8.6, 0.22), lit(Color("2b333b"), 0.0), poles)
	batch("LampHeads", Vector3(0.5, 0.18, 1.5), lit(Color("fff0c8"), 3.5), heads)
	if pools.is_empty():
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 0.78, 0.5, 0.55)
	material.disable_receive_shadows = true
	var mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(1, 1))
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = pools.size()
	for i in range(pools.size()):
		instances.set_instance_transform(i, pools[i])
	var node := MultiMeshInstance3D.new()
	node.name = "LampLightPools"
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches.append(node)


# A neon arch over the road before each tight bend: it marks where to start the slide.
func make_gates() -> void:
	var posts: Array[Transform3D] = []
	var bars: Array[Transform3D] = []
	var strips: Array[Transform3D] = []
	for d in drift_gates:
		var half: float = track.half_width(d) + track.rail_setback(d, 1.0) + 0.8
		var base := pose(d, 0.0, 0.0)
		for side in [-1.0, 1.0]:
			posts.append(base.translated_local(Vector3(side * half, 3.2, 0)))
		bars.append(base.translated_local(Vector3(0, 6.7, 0)).scaled_local(Vector3(half * 2 + 1.0, 1.8, 0.5)))
		var sign := Label3D.new()
		var bend: float = track.curvature(d + 50)
		sign.text = "< LEFT CURVE / DRIFT" if bend > 0 else "DRIFT / RIGHT CURVE >"
		sign.font = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
		sign.font_size = 96
		sign.pixel_size = .016
		sign.modulate = Color("ffd185")
		sign.transform = base * Transform3D(Basis.IDENTITY, Vector3(0, 6.7, .35))
		sign.name = "DriftDirection" + str(get_child_count())
		add_child(sign)
		strips.append(base.translated_local(Vector3(0, 5.6, 0)).scaled_local(Vector3(half * 2 - 1.0, 0.12, 0.2)))
	batch("DriftGatePosts", Vector3(0.5, 6.4, 0.5), lit(Color("1b2630"), 0.2), posts)
	batch("DriftGateBars", Vector3(1, 1, 1), lit(Color("152433"), 0.12), bars)
	batch("DriftGateStrips", Vector3(1, 1, 1), lit(Color("32e6ff"), 3.0), strips)
