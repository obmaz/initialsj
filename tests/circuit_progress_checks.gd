extends RefCounted
const Progress = preload("res://scripts/circuit_progress.gd")
const Report = preload("res://tests/report.gd")
var failures := 0
var assertions := 0

class CrossingCourse extends Node3D:
	var curve := Curve3D.new()
	var length := 0.0
	func _init() -> void:
		curve.bake_interval = 0.4
		for i in range(769):
			var t := TAU*i/768
			curve.add_point(Vector3(170*sin(t),20+6*cos(t),115*sin(t*2)))
		length = curve.get_baked_length()
	func point(d: float, offset: float = 0) -> Vector3:
		var at := fposmod(d,length)
		var center := curve.sample_baked(at)
		var forward := curve.sample_baked(fposmod(at+0.5,length))-curve.sample_baked(fposmod(at-0.5,length))
		var right := Vector3(-forward.z,0,forward.x).normalized()
		return center+right*offset+Vector3.UP*offset*tan(bank_at(d))
	func half_width(_d: float) -> float: return 7.0
	func bank_at(d: float) -> float: return 0.12*sin(TAU*fposmod(d,length)/length)
	func rail_setback(_d: float, _side: float) -> float: return 1.5

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error(message)

func drive(progress: RefCounted, road: Node3D, begin: float, end: float, step: float) -> void:
	var d := begin
	while (d < end if step > 0 else d > end):
		d = minf(end,d+step) if step > 0 else maxf(end,d+step)
		var result: Dictionary = progress.update(road.point(d,2),absf(step)/60)
		check(result.valid,"Ordinary physically plausible forward/reverse motion must retain valid telemetry")

func missed_gate_checks(progress: RefCounted, road: Node3D) -> Array:
	var rows := []
	for already_credited in [0,17]:
		progress.reset(80)
		var span: float = road.length/Progress.GATE_COUNT
		drive(progress,road,80,80+already_credited*span+4,2)
		check(progress.gates_passed == already_credited,"The missed-gate fixture must begin with the intended ordered credit")
		var gate: float = progress.next_gate
		var old_laps: int = progress.laps
		drive(progress,road,progress.distance,gate-36,2)
		var d: float = gate-36
		var invalid := 0
		while d < gate+36:
			d += 1
			var blend := smoothstep(gate-36,gate-10,d)*(1-smoothstep(gate+10,gate+36,d))
			var outside: float = road.half_width(d)+road.rail_setback(d,1)+0.8
			var lane := lerpf(2,outside,blend)
			var data: Dictionary = progress.update(road.point(d,lane),1.0/30)
			check(data.trackable,"A bounded continuous missed-gate excursion must retain physical telemetry")
			if not data.valid: invalid += 1
		check(invalid > 0 and progress.gates_passed == already_credited and progress.laps == old_laps,"An invalid required-gate crossing must award no credit or erase earned laps")
		check(absf(progress.next_gate-(gate+road.length)) < 0.001,"The same missed checkpoint must be retried on the next circuit")
		drive(progress,road,progress.distance,gate+road.length+4,2)
		check(progress.gates_passed == already_credited+1,"A later valid crossing must earn the missed gate exactly once")
		check(absf(progress.next_gate-(gate+road.length+span)) < 0.001,"After a retry the next checkpoint must preserve the postponed lap offset")
		var target_laps := 2 if already_credited == 0 else 3
		drive(progress,road,progress.distance,80+(target_laps+1)*road.length+4,2)
		check(progress.laps == target_laps and progress.gates_passed == target_laps*Progress.GATE_COUNT,"A recovered missed gate must allow an eventual complete race without shortcut lap credit")
		rows.append({"credited_before_miss":already_credited,"invalid_frames":invalid,"completed_valid_laps":progress.laps,"extra_circuit_required":1})
	return rows

func actual_shoulder_checks() -> Dictionary:
	var road := preload("res://scripts/road_section.gd").new()
	road.closed_loop = true
	road.course_id = 0
	preload("res://scripts/fuji_course.gd").build(road)
	var progress := Progress.new()
	progress.configure(road)
	var begin: float = road.length*0.10
	progress.reset(begin)
	progress.update(road.point(begin),1.0/30)
	# This dirt strip is outside the former width+4 acceptance but inside the
	# visible and physical 6.5 m setback. Stay there longer than the search window.
	for i in range(1,9):
		var d: float = begin+i
		progress.update(road.point(d,minf(i*2,road.half_width(d)+5)),1.0/30)
	var first_gate: float = progress.next_gate
	var d := begin+8
	while d < first_gate+8:
		d = minf(first_gate+8,d+2)
		var data := progress.update(road.point(d,road.half_width(d)+5)-Vector3.UP*0.025,1.0/30)
		check(data.valid and absf(float(data.distance)-d) < 0.4,"Continuous legal Fuji dirt driving must follow the curve beyond the local search window")
	check(progress.gates_passed == 1,"A gate crossed on real dirt inside the set-back barrier must count")
	var shoulder_distance: float = progress.distance
	for i in range(1,9):
		d += 1
		var data := progress.update(road.point(d,maxf(0,road.half_width(d)+5-i*2)),1.0/30)
		check(data.valid,"Returning from long legal dirt driving must remain valid without a rescue or teleport")
	drive(progress,road,d,begin+road.length*2+4,2)
	check(progress.laps == 2 and progress.gates_passed == 24,"Legal dirt gate credit must allow later ordinary gates and laps to continue")
	# The slightly wider telemetry envelope must never turn an outside-rail
	# crossing into gate credit, even when every world-space step is continuous.
	progress.reset(begin)
	var gate: float = progress.next_gate
	drive(progress,road,begin,gate-18,2)
	var last := {}
	for i in range(1,12):
		d = gate-18+i*2
		var lane: float = minf(2+i*2,road.half_width(d)+road.rail_setback(d,1)+0.8)
		last = progress.update(road.point(d,lane),1.0/30)
	check(last.trackable and not last.valid and absf(float(last.distance)-d) < 0.5,"Telemetry may follow the bounded flat runoff beyond a barrier without accepting that road position")
	check(progress.gates_passed == 0 and progress.laps == 0,"Crossing a gate outside the actual barrier cannot earn shortcut credit")
	var metrics := {"legal_shoulder_m":shoulder_distance-begin,"completed_laps_after_shoulder":2,"outside_rail_gate_credit":progress.gates_passed}
	road.free()
	return metrics

func run(tree: SceneTree) -> int:
	var road := CrossingCourse.new()
	tree.root.add_child(road)
	var progress := Progress.new()
	progress.configure(road)
	var upper := progress.sample(road.point(0,5),0)
	var lower := progress.sample(road.point(road.length/2,5),road.length/2)
	check(upper.valid and lower.valid,"Both crossing decks must project with their own local progress hints")
	check(upper.ground_height-lower.ground_height > 11,"The crossing fixture must have independently separated world heights")
	check(absf(float(upper.distance)) < 0.7 and absf(float(lower.distance)-road.length/2) < 0.7,"Deck projection must not jump to another part of the figure eight")
	check(not progress.sample(road.point(0,5),road.length/2).valid,"A car on the upper deck must not count as driving the lower deck")
	check(absf(float(progress.sample(road.point(320,6),320).lane)-6) < 0.2,"Banked road-space lateral telemetry must match the physical lane offset")
	for deck in [0.0,road.length/2]:
		progress.reset(deck-10)
		for i in range(11):
			var d: float = deck-10+i*2
			var data := progress.update(road.point(d,3),1.0/30)
			check(data.valid and absf(float(data.ground_height)-road.point(d,3).y) < 0.08,"The continuous fast projection must preserve the correct bridge deck")
		check(progress.fast_updates >= 9,"Ordinary consecutive crossing samples should use the bounded nearby search")
		var before_fallback: int = progress.full_searches
		var other_deck := road.point(deck+10,3)+Vector3.UP*(-12 if deck == 0 else 12)
		var mismatch := progress.update(other_deck,1.0/60)
		check(not mismatch.valid and progress.full_searches > before_fallback,"A deck-height discontinuity must fall back and reject the wrong road")
	progress.reset(80)
	var airborne := progress.update(road.point(80,2)+Vector3.UP*3,1.0/30)
	check(airborne.valid,"A normal short jump must remain measurable without snapping the car down")
	var airborne_input := road.point(80,2)+Vector3.UP*3
	progress.sample(airborne_input,80)
	check(airborne_input.is_equal_approx(road.point(80,2)+Vector3.UP*3),"Telemetry must not alter the world-space vehicle position")
	progress.reset(80)
	drive(progress,road,80,80+road.length*3+4,2)
	check(progress.laps == 3 and progress.gates_passed == 36,"Three complete forward laps must cross all 36 ordered gates")
	check(absf(progress.distance-(80+road.length*3+4)) < 0.25,"Unwrapped distance must retain completed laps")
	var forward_samples := ceili((road.length*3+4)/2)
	var fast_samples: int = progress.fast_updates
	var full_searches: int = progress.full_searches
	check(fast_samples >= forward_samples*0.95 and full_searches <= forward_samples*0.05,"Continuous ordinary laps must rarely require the expensive wide-window search")
	progress.reset(80)
	var rescue_at := 80+road.length*1.3
	drive(progress,road,80,rescue_at,2)
	var credited: int = progress.gates_passed
	progress.reposition(rescue_at-3)
	check(progress.laps == 1 and progress.gates_passed == credited,"Rescuing a car must preserve earned laps and gate credit")
	drive(progress,road,rescue_at-3,80+road.length*2+4,2)
	check(progress.laps == 2,"The lap after a rescue must finish at the original start line")
	progress.reset(80)
	drive(progress,road,80,80-road.length-4,-2)
	check(progress.laps == 0 and progress.gates_passed == 0,"Driving a complete lap in reverse must not earn a lap")
	progress.reset(80)
	for i in range(400): progress.update(road.point(80+(-1 if i%2 else 1)),1.0/60)
	check(progress.laps == 0 and progress.gates_passed == 0,"Oscillating around the finish line cannot farm laps")
	progress.reset(80)
	var shortcut := progress.update(road.point(80+road.length*0.5),1.0/60)
	check(not shortcut.valid and progress.laps == 0 and is_equal_approx(progress.distance,80),"Teleporting to a distant road must not credit skipped gates or progress")
	var offroad := progress.update(road.point(82,35),1.0/60)
	check(not offroad.valid and is_equal_approx(progress.distance,80),"Leaving the drivable road must preserve the last accepted progress")
	var below := progress.sample(road.point(80)-Vector3.UP*3,80)
	check(not below.valid,"Falling through or below the road cannot record valid progress")
	var missed_gates := missed_gate_checks(progress,road)
	var shoulder_metrics := actual_shoulder_checks()
	FileAccess.open(Report.path("circuit-progress-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"synthetic_crossing_length_m":road.length,"crossing_deck_clearance_m":upper.ground_height-lower.ground_height,"ordered_gates_per_lap":Progress.GATE_COUNT,"forward_lap_fast_samples":fast_samples,"forward_lap_wide_samples":full_searches,"actual_fuji_shoulders":shoulder_metrics,"missed_gate_recovery":missed_gates},"\t")+"\n")
	road.queue_free()
	await tree.process_frame
	print("World-space circuit projection / bridge deck identity / ordered lap gates: ","PASS" if failures == 0 else "FAIL")
	return failures
