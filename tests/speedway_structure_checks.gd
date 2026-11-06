extends RefCounted
const Report = preload("res://tests/report.gd")
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
	check(scenery.has_node("SpeedwayInnerGround"),"Elevated inside shoulders need actual banks down to the infield")
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
		for lane in [16.5,36.0,62.0,84.0,120.0,144.0,190.0,239.9]:
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
			if lane == 239.9: check(absf(height-6.5) < 0.04,"The final ten centimetres of the berm must approach the base plane")
			probes += 1
	var inner: MeshInstance3D = scenery.get_node("SpeedwayInnerGround")
	var inner_faces := inner.mesh.get_faces()
	for fraction in [0.025,0.15,0.265,0.52,0.75,0.83]:
		var d: float = race.track.length*fraction
		for lane in [-16.5,-45.0,-70.0,-105.0,-140.0,-179.9]:
			var position: Vector3 = race.track.point(d,lane)
			var height := mesh_height(inner_faces,Vector2(position.x,position.z))
			check(not is_nan(height),"Actual inside ground must cover elevated pits, palms and slope footprints")
			if is_nan(height): continue
			var error: float = absf(height-scenery.inner_ground_height(d,lane))
			worst_error = maxf(worst_error,error)
			check(error < 0.08,"Inner prop placement must follow the actual elevated ground within eight centimetres")
			if lane == -179.9: check(absf(height-6.5) < 0.04,"The inside embankment must end on the lake and lawn elevation")
	for placement: Dictionary in scenery.get_node("SpeedwayPalms").placements:
		var p: Vector3 = placement.position
		var height := mesh_height(inner_faces,Vector2(p.x,p.z))
		check(not is_nan(height) and p.y-height > 0.02 and p.y-height < 0.18,"Every palm must sit on its actual rolling infield bank")
	var tower: Node3D = scenery.get_node("RaceControlTower")
	var tower_floor := mesh_height(inner_faces,Vector2(tower.position.x,tower.position.z))
	check(not is_nan(tower_floor) and absf(tower.position.y-tower_floor-0.05) < 0.08,"Race control must share the elevated pit foundation")
	check(scenery.grandstand_anchors.size() == 10,"Every grandstand needs a shared rigid foundation")
	for frame: Transform3D in scenery.grandstand_anchors:
		for x in [34.4,47.55,60.7]:
			for z in [-58.0,-43.5,-29.0,-14.5,0.0,14.5,29.0,43.5,58.0]:
				var p := frame*Vector3(x,0,z)
				var height := mesh_height(faces,Vector2(p.x,p.z))
				check(not is_nan(height) and frame.origin.y+0.01 >= height,"Actual rolling terrain must not bury the front seating tier")
	FileAccess.open(Report.path("speedway-structure-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"exterior_mesh_probes":probes,"maximum_ground_mesh_error_m":worst_error,"grandstand_foundations":scenery.grandstand_anchors.size()},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("Speedway actual ground / light footings / rigid stand foundations: ","PASS" if failures == 0 else "FAIL")
	return failures
