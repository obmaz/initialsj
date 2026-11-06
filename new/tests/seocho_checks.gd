extends RefCounted
const Course = preload("res://scripts/seocho_course.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.open_courses()
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = race.hud.COURSE_SEOCHO.get_center()*race.hud.ui_scale()+race.hud.ui_offset()
	race.hud.handle_pointer(tap)
	tap.pressed = false
	race.hud.handle_pointer(tap)
	check(race.selected_course == 1 and race.track.scenery.theme == "seocho","Second circuit must select its own real-map environment")
	check(race.track.length > 6200 and race.track.length < 6900,"The mapped loop must preserve its real-world scale")
	var last := -1.0
	for place in race.track.scenery.PLACES:
		var p: Vector3 = Course.project(place)
		var d: float = race.track.active.curve.get_closest_offset(p)
		check(d > last and race.track.point(d).distance_to(p) < 26,"Map place %s: offset %.1f, order %.1f > %.1f" % [place.name,race.track.point(d).distance_to(p),d,last])
		last = d
	var waypoint_metrics := []
	for place in race.track.scenery.PLACES:
		var p: Vector3 = Course.project(place)
		var d: float = race.track.active.curve.get_closest_offset(p)
		waypoint_metrics.append({"name":place.name,"distance_m":d,"offset_from_road_m":race.track.point(d).distance_to(p)})
	var narrow := INF
	var wide := 0.0
	var tightest := 0.0
	for i in range(1500):
		var d: float = race.track.length*i/1500
		var w: float = race.track.half_width(d)
		narrow = minf(narrow,w); wide = maxf(wide,w)
		tightest = maxf(tightest,absf(race.track.curvature(d)))
		check(not race.track.active.in_tunnel(d),"The map prototype must not invent a Fuji tunnel in Seocho")
	check(narrow >= 5.1 and wide-narrow > 3,"Mido side road must be visibly narrower than the main avenues")
	check(race.track.point(0).distance_to(race.track.point(race.track.length)) < 0.01,"The second circuit must close without a positional jump")
	check(race.track.active.curve.get_baked_length() > 6200,"Baked road geometry must retain the full loop")
	for index in range(3):
		check(Catalog.record_key(index,"track",1) != Catalog.record_key(index,"track",0),"Seocho records must not overwrite Fuji records")
	FileAccess.open("res://docs/seocho-course-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"length_m":race.track.length,"minimum_half_width_m":narrow,"maximum_half_width_m":wide,"tightest_sampled_radius_m":1/tightest,"waypoints":waypoint_metrics},"\t")+"\n")
	var pad_count := 0
	race.choose_mode("tour")
	for f in race.track.active.features:
		if f.kind == "boost": pad_count += 1
	check(pad_count == 2,"Tour stage one must have a boost pad on each side")
	var pads: Array = race.track.active.features.filter(func(f): return f.kind == "boost")
	check(pads[0].lane*pads[1].lane < 0 and absf(pads[0].distance-pads[1].distance) >= 90,"Opposite pads must be staggered and cannot stack their entry impulses")
	race.state = "racing"
	race.set_physics_process(true)
	await tree.physics_frame
	await tree.physics_frame
	check(is_equal_approx(Engine.time_scale,1.2),"Racing must use the requested 20 percent faster simulation tempo")
	race.pause_tour()
	await tree.physics_frame
	await tree.physics_frame
	check(is_equal_approx(Engine.time_scale,1.0),"Pausing must restore ordinary UI timing")
	race.set_physics_process(false)
	race.queue_free()
	await tree.process_frame
	check(is_equal_approx(Engine.time_scale,1.0),"Leaving the scene must restore engine time scale")
	print("Seocho map / course selection / pace checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures," / tightest sampled radius ",1/maxf(tightest,0.0001))
	return failures
