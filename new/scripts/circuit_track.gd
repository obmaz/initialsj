extends "res://scripts/track.gd"
# Restore the original Fuji lakeside loop as the single TRACK circuit.
func reset(_stage: int = 0, _node_index: int = 0) -> void:
	for node in [active,previous,sibling]:
		if is_instance_valid(node): node.queue_free()
	for node in previews:
		if is_instance_valid(node): node.queue_free()
	previews.clear()
	history.clear()
	previous = null
	sibling = null
	active = Section.new()
	active.closed_loop = true
	active.curve.clear_points()
	for i in range(361):
		var a := TAU*i/360.0
		active.curve.add_point(Vector3(sin(a)*(300+37*sin(a*3)),10+7*sin(a*2),cos(a)*380))
	active.length = active.curve.get_baked_length()
	add_child(active)
	update_ground()
func build_previews() -> void: pass
func maintain(_distance: float) -> void: pass
func update_ground() -> void:
	if base_material != null: base_material.albedo_color = Color("617f65")
