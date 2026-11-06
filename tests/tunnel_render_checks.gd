extends RefCounted
const Report = preload("res://tests/report.gd")
const Rig = preload("res://scripts/tunnel_lights.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var report := []
	for mode in ["track","tour"]:
		race.choose_mode(mode)
		if mode == "tour": race.track.reset(1,1)
		var section: Node3D = race.track.active
		var count := 0
		var closest_wall_gap := INF
		for i in range(section.curve_marker_distances.size()):
			if not section.curve_marker_tunnel[i]: continue
			count += 1
			var d: float = section.curve_marker_distances[i]
			var transform: Transform3D = section.curve_marker_transforms[i]
			var f: Vector3 = (section.point(d+1)-section.point(d-1)).normalized()
			var right := Vector3(-f.z,0,f.x).normalized()
			var side := signf((transform.origin-section.point(d)).dot(right))
			check(transform.basis.z.normalized().dot(-right*side) > 0.99,"Tunnel arrow boards must face across the road from the wall")
			# Sample the real curved wall alignment at both ends of the 3m board.
			for end in [-1.0,1.0]:
				var corner: Vector3 = transform*Vector3(end*1.5,0,0)
				var nearest := d
				var best := INF
				for step in range(-20,21):
					var at := d+step*0.2
					var p: Vector3 = section.point(at)
					var gap := Vector2(corner.x-p.x,corner.z-p.z).length_squared()
					if gap < best: best = gap; nearest = at
				var center: Vector3 = section.point(nearest)
				var direction: Vector3 = (section.point(nearest+1)-section.point(nearest-1)).normalized()
				var normal := Vector3(-direction.z,0,direction.x).normalized()
				var gap: float = section.half_width(nearest)+(1.25 if section.closed_loop else 2.4)-absf((corner-center).dot(normal))
				closest_wall_gap = minf(closest_wall_gap,gap)
				check(gap > 0.06,"Both corners of a tunnel sign must clear the curved wall")
		check(count >= 3,"Regression needs several actual wall-mounted signs in both tunnel types")
		var rig: Node3D = Rig.collect_rigs(section)[0]
		var p: Vector3 = section.point((rig.span.x+rig.span.y)*0.5)+Vector3.UP*2
		rig.update_lights(p)
		var changes: int = rig.visibility_changes
		for frame in range(120): rig.update_lights(p)
		check(rig.visibility_changes == changes,"Stationary tunnel camera must not churn light visibility every frame")
		var visible := 0
		for light in rig.lights:
			if light.visible: visible += 1
		check(visible > 0 and visible <= Rig.MAX_NEARBY,"Only the nearest local light budget may be active")
		for light in rig.lights: check(not light.shadow_enabled,"Tunnel local lights must not allocate point-light shadows")
		report.append({"mode":mode,"wall_signs":count,"minimum_sign_to_wall_gap_m":closest_wall_gap,"light_count":rig.lights.size(),"active_lights":visible,"visibility_changes_over_120_stationary_updates":rig.visibility_changes-changes})
	race.queue_free()
	await tree.process_frame
	FileAccess.open(Report.path("tunnel-render-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"failures":failures},"\t")+"\n")
	print("Tunnel sign clearance / light visibility churn checks: ","PASS" if failures == 0 else "FAIL")
	return failures
