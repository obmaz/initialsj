extends RefCounted
# Every course alternates wide and narrow stretches, and the change is gradual enough to drive.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func survey(track: Node3D, label: String, minimum_spread: float) -> void:
	var section = track.active
	var low := INF
	var high := -INF
	var steepest := 0.0
	var previous: float = section.half_width(0.0)
	var step := 5.0
	var d := step
	while d <= section.length:
		var width: float = section.half_width(d)
		low = minf(low,width)
		high = maxf(high,width)
		steepest = maxf(steepest,absf(width-previous)/step)
		previous = width
		d += step
	check(high-low >= minimum_spread,"%s needs clearly wide and narrow stretches (%.1f to %.1f)" % [label,low,high])
	check(low >= 6.0,"%s must never pinch below a car-and-a-half lane (%.1f)" % [label,low])
	check(steepest < 0.045,"%s width must change gradually (%.3f m per m)" % [label,steepest])

func run(tree: SceneTree) -> int:
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	r.choose_mode("track",0)
	await tree.physics_frame
	survey(r.track,"Fuji",3.5)
	check(absf(r.track.active.half_width(0.0)-r.track.active.half_width(r.track.length-0.01)) < 0.05,"Fuji width must close seamlessly at the start line")
	r.choose_mode("track",1)
	await tree.physics_frame
	survey(r.track,"Suncoast",3.5)
	check(absf(r.track.active.half_width(0.0)-14.5) < 0.01 and absf(r.track.active.half_width(r.track.length*0.05)-14.5) < 0.01,"Suncoast must keep full width along the pit lane")
	r.choose_mode("tour",0)
	await tree.physics_frame
	survey(r.track,"Tour",3.5)
	check(absf(r.track.active.half_width(0.0)-9.0) < 0.01 and absf(r.track.active.half_width(r.track.length)-9.0) < 0.01,"Tour sections must join at a common width")
	r.queue_free()
	await tree.process_frame
	print("Road width alternates wide and narrow / gradual / seamless: ","PASS" if failures == 0 else "FAIL")
	return failures
