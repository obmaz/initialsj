extends Node3D
const Section = preload("res://scripts/road_section.gd")
const Library = preload("res://scripts/route_library.gd")
var active: Section
var previous: Section
var sibling: Section
var previews: Array[Section] = []
var history: Array[int] = []
var base_material: StandardMaterial3D
var ground_plane: MeshInstance3D
var length: float:
	get: return active.length
var scenery: Node3D:
	get: return active.scenery
var road_surface: MeshInstance3D:
	get: return active.road_surface
var prop_batches: Array[MultiMeshInstance3D]:
	get: return active.prop_batches

func _ready() -> void:
	reset()
	var base := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50000,50000)
	base.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6e8563")
	material.roughness = 1
	base.material_override = material
	base_material = material
	base.position.y = -5
	ground_plane = base
	add_child(base)
	update_ground()

func disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children(): disable_collisions(child)

func retire(node: Node) -> void:
	disable_collisions(node)
	node.queue_free()

func _exit_tree() -> void:
	disable_collisions(self)

func reset(stage: int = 0, node_index: int = 0) -> void:
	for node in [active,previous,sibling]:
		if is_instance_valid(node): retire(node)
	for node in previews:
		if is_instance_valid(node): retire(node)
	previews.clear()
	history.clear()
	previous = null
	sibling = null
	for i in range(stage): history.append(1 if i < node_index else 0)
	active = Section.new(Vector3(0,6,0),-PI/2,stage,node_index)
	add_child(active)
	add_world_collision(active)
	build_previews()
	update_ground()

func add_world_collision(section: Section) -> void:
	section.add_child(preload("res://scripts/fuji_collision.gd").build(section))

func update_ground() -> void:
	if base_material != null:
		var theme_id := Library.theme(active.stage,active.route_node)
		var urban_colors := {"city":"505963","seoul":"64665f","ruins":"5c6256","neon":"232932"}
		if urban_colors.has(theme_id): base_material.albedo_color = Color(urban_colors[theme_id])
		else: base_material.albedo_color = Color("125a79") if Library.coastal(theme_id) else Color(Library.PALETTES[theme_id]).darkened(0.2)

func build_previews() -> void:
	if not previews.is_empty() or active.stage >= Library.STAGES - 1: return
	for side in [0,1]:
		var section := Section.new(active.point(active.length),active.heading(active.length),active.stage+1,active.route_node+side,-1 if side == 0 else 1)
		add_child(section)
		add_world_collision(section)
		previews.append(section)

func maintain(distance: float) -> void:
	if distance > 180: build_previews()
	if distance > 420:
		if is_instance_valid(sibling): retire(sibling)
		sibling = null
		if is_instance_valid(previous): retire(previous)
		previous = null

func point(distance: float, lane: float = 0) -> Vector3:
	if distance < 0 and is_instance_valid(previous): return previous.point(previous.length+distance,lane)
	if distance <= active.length or previews.size() != 2: return active.point(distance,lane)
	var d := distance-active.length
	var center := (previews[0].point(d)+previews[1].point(d)) / 2
	var next := (previews[0].point(d+2)+previews[1].point(d+2)) / 2
	var f := (next-center).normalized()
	return center + Vector3(-f.z,0,f.x).normalized() * lane

func heading(distance: float) -> float:
	var f := point(distance+2)-point(distance-2)
	return atan2(-f.x,-f.z)

func curvature(distance: float) -> float:
	return wrapf(heading(distance+12)-heading(distance-12),-PI,PI) / 24

func traffic_point(distance: float, lane: float, side: int = 0) -> Vector3:
	if distance > active.length and previews.size() == 2: return previews[clampi(side,0,1)].point(distance-active.length,lane)
	return point(distance,lane)

func half_width(distance: float) -> float:
	if distance < 0 and is_instance_valid(previous): return previous.half_width(previous.length+distance)
	if distance > active.length and previews.size() == 2:
		var d := distance-active.length
		return previews[0].point(d).distance_to(previews[1].point(d))*0.5+minf(previews[0].half_width(d),previews[1].half_width(d))
	return active.half_width(distance)

func advance(side: int, distance: float, lane: float) -> Dictionary:
	var world := point(distance,lane)
	var old_length := active.length
	if is_instance_valid(previous): retire(previous)
	if is_instance_valid(sibling): retire(sibling)
	previous = active
	active = previews[side]
	sibling = previews[1-side]
	sibling.scenery.set_ground_enabled(false)
	active.scenery.set_ground_enabled(true)
	previews.clear()
	history.append(side)
	update_ground()
	var d := distance-old_length
	var forward := (active.point(d+2)-active.point(d)).normalized()
	d += (world-active.point(d)).dot(forward)
	var right := Vector3(-forward.z,0,forward.x).normalized()
	return {"distance":d,"lane":(world-active.point(d)).dot(right),"old_length":old_length,"sibling":sibling}

func reconsider(distance: float, lane: float) -> Dictionary:
	if distance >= 150 or not is_instance_valid(sibling): return {}
	var world := point(distance,lane)
	if world.distance_to(sibling.point(distance)) + 0.7 >= world.distance_to(active.point(distance)): return {}
	var old := active
	active = sibling
	sibling = old
	sibling.scenery.set_ground_enabled(false)
	active.scenery.set_ground_enabled(true)
	history[-1] = 0 if active.entry_side < 0 else 1
	update_ground()
	var f := (active.point(distance+2)-active.point(distance)).normalized()
	var d := distance + (world-active.point(distance)).dot(f)
	var right := Vector3(-f.z,0,f.x).normalized()
	return {"distance":d,"lane":(world-active.point(d)).dot(right)}
