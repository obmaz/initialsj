extends "res://scripts/track/track.gd"
# Closed circuits share race rules: Fuji uses an elevated road; Suncoast builds a banked tri-oval.
var course_id := 0
var map_bounds := Rect2()
var world_collision: Node3D


func reset(_stage: int = 0, _node_index: int = 0) -> void:
	for node in [active, previous, sibling]:
		if is_instance_valid(node):
			retire(node)
	for node in previews:
		if is_instance_valid(node):
			retire(node)
	previews.clear()
	history.clear()
	previous = null
	sibling = null
	active = Section.new()
	active.closed_loop = true
	active.course_id = course_id
	if course_id == 1:
		preload("res://scripts/track/speedway_course.gd").build(active)
	elif course_id == 2:
		preload("res://scripts/track/night_course.gd").build(active)
	elif course_id == 3:
		preload("res://scripts/track/riviera_course.gd").build(active)
	elif course_id == 4:
		preload("res://scripts/track/gorge_course.gd").build(active)
	else:
		preload("res://scripts/track/fuji_course.gd").build(active)
	map_bounds = Rect2(Vector2(active.point(0).x, active.point(0).z), Vector2.ZERO)
	for sample in range(800):
		var p := active.point(active.length * sample / 800)
		map_bounds = map_bounds.expand(Vector2(p.x, p.z))
	add_child(active)
	# All circuits are driven by real 3D physics on their actual road and rail triangles.
	world_collision = preload("res://scripts/physics/world_collision.gd").build(active)
	active.add_child(world_collision)
	update_ground()


func build_previews(_staged: bool = false) -> void:
	pass


func maintain(_distance: float) -> void:
	pass


func update_ground() -> void:
	# The night circuit sits on a raised harbour floor under its embankments.
	if ground_plane != null:
		ground_plane.position.y = 3.2 if course_id == 2 else -5.0
	if base_material != null:
		base_material.albedo_color = (
			Color("0b1018") if course_id == 2 else (Color("548e5d") if course_id == 1 else Color("617f65"))
		)
