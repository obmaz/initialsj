extends RefCounted
const Report = preload("res://tests/report.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var track = load("res://scripts/track/circuit_track.gd").new()
	tree.root.add_child(track)
	var section: Node3D = track.active
	check(track.world_collision != null,"Fuji must create actual world collision geometry")
	check(track.world_collision.get_child_count() == 2,"One ground and one wall body must cover the whole course")
	var lower: Vector3 = section.point(section.bridge_lower_distance)
	var upper: Vector3 = section.point(section.bridge_upper_distance)
	check(Vector2(lower.x-upper.x,lower.z-upper.z).length() < 0.05,"The elevated route must really cross the lower route in plan view")
	check(upper.y-lower.y > 25,"The crossover needs visible height and safe underside clearance")
	check(section.scenery.has_node("BridgeDeck") and section.scenery.has_node("BridgePiers"),"A visible solid bridge must connect the elevated roadway")
	var low := INF
	var high := -INF
	var bank := 0.0
	for i in range(1000):
		var d: float = section.length*i/1000
		low = minf(low,section.point(d).y)
		high = maxf(high,section.point(d).y)
		bank = maxf(bank,absf(section.bank_at(d)))
		if section.on_bridge(d):
			check(is_equal_approx(section.rail_setback(d,-1),1.5) and is_equal_approx(section.rail_setback(d,1),1.5),"Bridge walls must sit over the actual deck rather than outside it")
	check(high-low > 55 and high-low < 70,"Fuji needs a substantial yet bounded elevation range")
	check(rad_to_deg(bank) > 8 and rad_to_deg(bank) < 15,"Fuji bends need real moderate bank angles")
	var tunnel_start: float = section.underpass_span().x
	check(section.point(tunnel_start-190).y-section.point(tunnel_start+60).y > 8,"The underpass approach must visibly descend below the original ground")
	check(section.point(tunnel_start+430).y-section.point(tunnel_start+180).y > 8,"The underpass exit must climb back out of the cutting")
	for lane in [-7.0,0.0,7.0]:
		check(section.point(-0.01,lane).distance_to(section.point(section.length-0.01,lane)) < 0.002,"Every banked lane must join across the lap seam")
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = track.get_world_3d().direct_space_state
	check(section.features.filter(func(f): return f.kind == "boost").size() >= 5,"Fuji must offer boost opportunities throughout the course")
	var ramps: Array = section.features.filter(func(f): return f.kind == "ramp")
	check(ramps.size() >= 3,"Fuji must include multiple optional jumps")
	for ramp in ramps:
		for fraction in [0.25,0.5,0.75]:
			var d: float = ramp.distance-ramp.length*0.5+ramp.length*fraction
			var p: Vector3 = section.point(d,ramp.lane)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*(ramp.height+1),p-Vector3.UP,1))
			check(not hit.is_empty() and absf(hit.position.y-p.y-ramp.height*fraction-0.025) < 0.06,"Every separately named ramp must have a real sloping collision surface matching its visible mesh")
	var samples := 0
	for d in [80.0,section.length*0.22,section.underpass_span().x+120,section.bridge_lower_distance,section.bridge_upper_distance,section.length*0.9]:
		for lane in [-4.0,0.0,4.0]:
			var p: Vector3 = section.point(d,lane)
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.5,p-Vector3.UP*2.5,1)
			var hit: Dictionary = space.intersect_ray(ray)
			check(not hit.is_empty(),"Physics must find a driving surface at each actual road sample")
			if hit.is_empty(): continue
			check(absf(hit.position.y-p.y) < 0.04,"Physics surface and visible road must agree within four centimetres")
			check(hit.normal.y > 0.8,"Road collision normals must face upward even on grades and banks")
			samples += 1
	# A cast from between the decks can only hit the lower road. There is no
	# invisible terrain ceiling/floor filling the genuine under-bridge corridor.
	var under := PhysicsRayQueryParameters3D.create(Vector3(lower.x,upper.y-3,lower.z),lower-Vector3.UP,1)
	var under_hit: Dictionary = space.intersect_ray(under)
	check(not under_hit.is_empty() and absf(under_hit.position.y-lower.y) < 0.04,"The space below the bridge must remain physically open")
	var deck_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(upper-Vector3.UP*6,upper-Vector3.UP*0.5,2))
	check(not deck_hit.is_empty() and upper.y-deck_hit.position.y < 2,"The visible bridge deck must also have a solid underside in physics")
	var wall_d: float = section.bridge_upper_distance
	var wall_start: Vector3 = section.point(wall_d,section.half_width(wall_d)-1)+Vector3.UP*0.7
	var wall_end: Vector3 = section.point(wall_d,section.half_width(wall_d)+4)+Vector3.UP*0.7
	var wall_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(wall_start,wall_end,2))
	check(not wall_hit.is_empty(),"A real wall must protect the upper deck edge")
	var tunnel_floor: Vector3 = section.point(tunnel_start+120)
	var roof_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(tunnel_floor+Vector3.UP*3,tunnel_floor+Vector3.UP*9,2))
	check(not roof_hit.is_empty() and roof_hit.position.y-tunnel_floor.y > 5.5,"The tunnel ceiling must be a real collision surface with clearance above the car")
	var water_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,4,0),Vector3(0,-8,0),1))
	check(water_hit.is_empty(),"Lake water and the distant visual base must not become an invisible driving plane")
	FileAccess.open(Report.path("fuji-geometry-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"length_m":section.length,"elevation_span_m":high-low,"maximum_bank_degrees":rad_to_deg(bank),"crossing_lower_distance_m":section.bridge_lower_distance,"crossing_upper_distance_m":section.bridge_upper_distance,"crossing_height_m":upper.y-lower.y,"road_raycast_samples":samples,"ground_triangles":track.world_collision.get_meta("ground_triangles"),"barrier_triangles":track.world_collision.get_meta("barrier_triangles"),"failures":failures},"\t")+"\n")
	track.queue_free()
	await tree.process_frame
	print("Fuji elevated crossover / actual road, wall and tunnel colliders: ","PASS" if failures == 0 else "FAIL")
	return failures
