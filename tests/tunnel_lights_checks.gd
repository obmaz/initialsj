extends RefCounted
const Rig = preload("res://scripts/rendering/tunnel_lights.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func collect(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node.get_script() == Rig: out.append(node)
	for child in node.get_children(): out.append_array(collect(child))
	return out
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for mode in ["track","tour"]:
		race.choose_mode(mode)
		if mode == "tour": race.track.reset(1,1)
		var rigs := collect(race.track.active.scenery)
		check(rigs.size() == 1,"Both the Fuji gallery and long Tour tunnels must use the shared light rig")
		if rigs.is_empty(): continue
		var rig: Node = rigs[0]
		var types := {}
		var families := {}
		for i in range(rig.lights.size()):
			types[rig.lights[i].get_class()] = true
			families[rig.families[i]] = true
		check(types.has("OmniLight3D") and types.has("SpotLight3D") and families.size() == 3,"Tunnel fixtures must include warm ceiling lamps, cool strips and directed work lights")
		for i in range(40):
			var d: float = lerpf(rig.span.x,rig.span.y,i/39.0)
			rig.update_lights(race.track.point(d)+Vector3.UP*2)
			var visible := 0
			for light in rig.lights:
				if light.visible: visible += 1
			check(visible > 0 and visible <= 6,"Tunnel illumination must stay present with no more than six nearby local lights")
		rig.update_lights(race.track.point(0)-Vector3.UP*100)
		for light in rig.lights: check(not light.visible,"Distant tunnel lights must be disabled")
	print("Tunnel lighting / three fixture families / light budget checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
