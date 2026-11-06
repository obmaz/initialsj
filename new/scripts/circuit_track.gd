extends "res://scripts/track.gd"
# One Fuji circuit: lakeside straight, climbing esses, ridge hairpin and downhill return.
const CONTROL_POINTS := [
	Vector3(-300,8,350),Vector3(0,8,350),Vector3(360,10,350),
	Vector3(540,18,280),Vector3(620,28,100),Vector3(570,38,-30),
	Vector3(450,44,-65),Vector3(300,43,-65),Vector3(210,39,-115),
	Vector3(230,35,-190),Vector3(320,31,-215),Vector3(485,27,-215),
	Vector3(600,22,-320),Vector3(540,16,-475),Vector3(350,12,-530),
	Vector3(60,10,-530),Vector3(-250,14,-500),Vector3(-450,23,-380),
	Vector3(-510,33,-220),Vector3(-400,36,-90),Vector3(-465,25,35),
	Vector3(-560,18,145),Vector3(-545,12,260),Vector3(-480,8,350)
]
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
	for i in range(CONTROL_POINTS.size()+1):
		var index := i%CONTROL_POINTS.size()
		var before: Vector3 = CONTROL_POINTS[posmod(index-1,CONTROL_POINTS.size())]
		var after: Vector3 = CONTROL_POINTS[(index+1)%CONTROL_POINTS.size()]
		var tangent := (after-before)/6
		active.curve.add_point(CONTROL_POINTS[index],-tangent,tangent)
	active.length = active.curve.get_baked_length()
	add_child(active)
	update_ground()
func build_previews() -> void: pass
func maintain(_distance: float) -> void: pass
func update_ground() -> void:
	if base_material != null: base_material.albedo_color = Color("617f65")
