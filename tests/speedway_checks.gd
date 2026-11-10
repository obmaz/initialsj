extends RefCounted
const Report = preload("res://tests/report.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.open_courses()
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = race.hud.COURSE_SPEEDWAY.get_center()*race.hud.ui_scale()+race.hud.ui_offset()
	race.hud.handle_pointer(tap)
	tap.pressed = false
	race.hud.handle_pointer(tap)
	check(race.selected_course == 1 and race.track.scenery.theme == "speedway","Second course touch must select the speedway")
	check(race.track.length > 4300 and race.track.length < 5200,"Speedway must have a full-size high speed lap")
	check(race.track.previews.is_empty(),"A circuit must never spawn Tour forks")
	var max_bank := 0.0
	var min_bank := INF
	var max_step := 0.0
	var radius := INF
	var lowest := INF
	var highest := -INF
	var maximum_grade := 0.0
	for i in range(1600):
		var d: float = race.track.length*i/1600
		var bank: float = race.track.active.bank_at(d)
		max_bank = maxf(max_bank,absf(bank))
		min_bank = minf(min_bank,absf(bank))
		max_step = maxf(max_step,absf(bank-race.track.active.bank_at(d-1)))
		radius = minf(radius,1/maxf(absf(race.track.curvature(d)),0.000001))
		lowest = minf(lowest,race.track.point(d).y)
		highest = maxf(highest,race.track.point(d).y)
		maximum_grade = maxf(maximum_grade,absf(race.track.point(d+2).y-race.track.point(d-2).y)/4)
		check(race.track.half_width(d) >= 7.4,"The oval needs a genuinely wide multi-lane surface")
		check(not race.track.active.in_tunnel(d),"Open speedway must not inherit the Fuji tunnel")
		var cross: Vector3 = race.track.point(d,10)-race.track.point(d,-10)
		check(absf(cross.y-20*tan(bank)) < 0.001,"The bank must be actual 3D road geometry")
	check(rad_to_deg(max_bank) > 24 and rad_to_deg(min_bank) < 2,"Turns must bank steeply and the back straight must flatten")
	check(max_step < 0.009 and radius > 110,"Bank transitions and curvature must support high speed racing")
	check(highest-lowest > 25 and highest-lowest < 40,"Suncoast must have meaningful rolling elevation while retaining a high-speed oval profile")
	check(maximum_grade > 0.045 and maximum_grade < 0.14,"Coastal climbs and descents must be noticeable and smooth enough for speedway racing")
	for lane in [-14.5,0.0,14.5]:
		check(race.track.point(-0.01,lane).distance_to(race.track.point(race.track.length-0.01,lane)) < 0.002,"Every banked lane must close seamlessly")
	check(absf(race.track.active.bank_at(-0.01)-race.track.active.bank_at(0.01)) < 0.001,"Banking must close without a roll jump")
	for path in ["SpeedwayInfield","SpeedwayInnerGround","InfieldLake","SpeedwaySafetyWalls","CatchFence","GrandstandSeats0","PitLane","PitGarages","RaceControlTower"]:
		check(race.track.scenery.has_node(path),"Missing actual speedway geometry: "+path)
	var stripe: MeshInstance3D = race.track.active.make_finish_stripe(race.track.length*0.793)
	var stripe_vertices: PackedVector3Array = stripe.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lowest_stripe := INF
	var highest_stripe := -INF
	for p in stripe_vertices:
		lowest_stripe = minf(lowest_stripe,p.y)
		highest_stripe = maxf(highest_stripe,p.y)
	check(highest_stripe-lowest_stripe > 6,"Full-width finish stripe must follow a real steep bank without flat tiles")
	check(stripe_vertices.size() >= 17*2*6,"Finish stripe must cover all speedway lanes with joined geometry")
	stripe.free()
	for index in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		check(Catalog.record_key(index,"track",1).begins_with("track_suncoast_"),"Replacement circuit needs its own record namespace")
		check(Catalog.record_key(index,"track",1) != Catalog.record_key(index,"track",0),"Speedway records must remain separate from Fuji")
	race.restart()
	race.state = "racing"
	var active := 0
	for r in race.rivals:
		if r.active: active += 1
	check(active == 15,"Speedway must use sixteen competitors while other circuits retain eight")
	# Lap counting and the three-lap finish are checked by a real drive in suncoast_world_checks.gd.
	FileAccess.open(Report.path("speedway-course-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"length_m":race.track.length,"elevation_span_m":highest-lowest,"maximum_grade":maximum_grade,"max_bank_degrees":rad_to_deg(max_bank),"min_bank_degrees":rad_to_deg(min_bank),"max_bank_change_rad_per_m":max_step,"tightest_radius_m":radius,"failures":failures},"\t")+"\n")
	race.queue_free()
	await tree.process_frame
	print("Speedway / banked geometry / touch selection / lap checks: ","PASS" if failures == 0 else "FAIL")
	return failures
