extends RefCounted
var failures := 0
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)
# Intersect the actual exported triangle geometry with a vertical probe. This
# deliberately does not trust the scenery's analytical height helper alone.
func mesh_height(faces: PackedVector3Array, at: Vector2) -> float:
	for i in range(0,faces.size(),3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i+1]
		var c: Vector3 = faces[i+2]
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var ac := Vector2(c.x-a.x,c.z-a.z)
		var p := at-Vector2(a.x,a.z)
		var det := ab.cross(ac)
		if absf(det) < 0.00001: continue
		var u := p.cross(ac)/det
		var v := ab.cross(p)/det
		if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001:
			return a.y+(b.y-a.y)*u+(c.y-a.y)*v
	return NAN
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",1)
	var scenery: Node3D = race.track.scenery
	check(scenery.has_node("SpeedwayOuterGround"),"Banked track needs actual exterior ground geometry")
	check(scenery.has_node("GrandstandFoundations") and scenery.has_node("GrandstandCanopySupports"),"Stands need solid foundations and supported canopies")
	var ground: MeshInstance3D = scenery.get_node("SpeedwayOuterGround")
	var faces := ground.mesh.get_faces()
	var lowest_vertex := INF
	for vertex in faces: lowest_vertex = minf(lowest_vertex,vertex.y)
	check(absf(lowest_vertex-6.5) < 0.0001,"The actual exterior mesh must end on the base plane")
	var worst_error := 0.0
	var probes := 0
	for fraction in [0.025,0.15,0.265,0.52,0.75,0.793,0.83]:
		var d: float = race.track.length*fraction
		for lane in [16.5,36.0,62.0,84.0,120.0,144.0,159.9]:
			var position: Vector3 = race.track.point(d,lane)
			var height := mesh_height(faces,Vector2(position.x,position.z))
			check(not is_nan(height),"Exterior ground must cover stand, light and slope footprints")
			if is_nan(height): continue
			var error: float = absf(height-scenery.outer_ground_height(d,lane))
			worst_error = maxf(worst_error,error)
			check(error < 0.08,"Analytical prop placement must agree with actual exterior mesh within eight centimetres")
			if lane == 84:
				var pole: Transform3D = scenery.pose(d,lane,12)
				check(absf(pole.origin.y-12-height) < 0.08,"Light poles must reach the actual ground")
			# Probe just inside the polygon edge: its eight-metre chords sit
			# slightly inside the analytic curve, and the final slope is linear.
			if lane == 159.9: check(absf(height-6.5) < 0.04,"The final ten centimetres of the berm must approach the base plane")
			probes += 1
	check(scenery.grandstand_anchors.size() == 10,"Every grandstand needs a shared rigid foundation")
	for frame: Transform3D in scenery.grandstand_anchors:
		for x in [34.4,47.55,60.7]:
			for z in [-58.0,-43.5,-29.0,-14.5,0.0,14.5,29.0,43.5,58.0]:
				var p := frame*Vector3(x,0,z)
				var at: float = race.track.active.curve.get_closest_offset(Vector3(p.x,8,p.z))
				check(frame.origin.y+0.01 >= scenery.outer_ground_height(at,x),"Terrain must not bury the front seating tier")
	FileAccess.open("res://docs/speedway-structure-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"exterior_mesh_probes":probes,"maximum_ground_mesh_error_m":worst_error,"grandstand_foundations":scenery.grandstand_anchors.size()},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("Speedway actual ground / light footings / rigid stand foundations: ","PASS" if failures == 0 else "FAIL")
	return failures
