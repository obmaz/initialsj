extends RefCounted
# Guardrail response scales with speed, and a car that ends up past the rail returns to the road.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func hit_road_space(r: Node3D, speed: float) -> Dictionary:
	r.restart()
	r.state = "racing"
	for rival in r.rivals: rival.active = false
	r.distance = 400
	r.lane = r.track.lane_limits(r.distance).y-0.01
	r.speed = speed
	r.lane_velocity = 8
	r.slip_angle = 0
	r.step(1.0/60,0,false,true,false)
	return {"lane_velocity":r.lane_velocity,"speed":r.speed,"slip":r.slip_angle}
func run(tree: SceneTree) -> int:
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	# Tour / Suncoast: the bounce, the speed lost and the nose swing grow with speed.
	r.choose_mode("tour")
	var slow := hit_road_space(r,30)
	var medium := hit_road_space(r,50)
	var fast := hit_road_space(r,70)
	check(absf(slow.lane_velocity) < absf(medium.lane_velocity) and absf(medium.lane_velocity) < absf(fast.lane_velocity),"A faster guardrail hit must bounce the car further inward")
	check(absf(fast.lane_velocity) > 12,"A fast guardrail hit must throw the car well clear of the rail")
	check(slow.speed/30.0 > fast.speed/70.0,"A faster hit must lose a larger share of its speed")
	check(absf(slow.slip) < absf(medium.slip) and absf(medium.slip) < absf(fast.slip),"A faster hit must swing the nose further")
	# A hard hit freezes the frame briefly; reduced motion skips it.
	r.restart()
	r.motion_reduced = false
	r.bump_cooldown = 0
	r.register_impact(0.9,Vector2(1,0))
	check(r.hitstop_until > Time.get_ticks_msec(),"A hard impact must freeze the frame briefly")
	r.restart()
	check(r.hitstop_until == 0 and r.return_flash == 0,"A restart must clear the freeze-frame")
	r.motion_reduced = true
	r.bump_cooldown = 0
	r.register_impact(0.9,Vector2(1,0))
	check(r.hitstop_until == 0,"Reduced motion must skip the freeze-frame")
	r.motion_reduced = false
	# Fuji: the car is thrown back from a real wall at a speed-dependent rate, and a car
	# that ends up beyond the guardrail line is put back on the road.
	r.choose_mode("track",0)
	r.restart()
	r.state = "racing"
	for rival in r.rivals: rival.active = false
	var world: Node3D = r.world_race
	world.safe_distance = 900.0
	world.safe_lane = 0.0
	var d := 700.0
	var side := 1.0
	var edge: float = r.track.half_width(d)+r.track.active.rail_setback(d,side)
	var outside_lane := edge+6.0
	world.teleport(0,d,outside_lane,false)
	await tree.physics_frame
	await tree.physics_frame
	var start_distance: float = r.distance
	for frame in range(120):
		world.update_outside(1.0/60)
	check(r.return_flash > 0 and r.state == "racing","A car beyond the guardrail must be returned to the road")
	await tree.physics_frame
	await tree.physics_frame
	for frame in range(4): world.step(1.0/60,0,false,false,false,false,false)
	check(absf(r.lane) < r.track.half_width(r.distance)+1.0,"The returned car must be on the road, not beside it")
	check(r.speed < 3 and r.state == "racing","The returned car starts from rest and the race continues")
	check(absf(r.distance-900.0) < 40.0,"The car must return to its last safe stretch (got %.0f, expected near 900)" % r.distance)
	# Being on the road never triggers it.
	r.return_flash = 0
	world.teleport(0,800.0,0.0,false)
	await tree.physics_frame
	for frame in range(120): world.update_outside(1.0/60)
	check(r.return_flash == 0,"A car on the road must never be returned")
	r.queue_free()
	await tree.process_frame
	print("Guardrail response scales with speed / spin / freeze-frame / return to road: ","PASS" if failures == 0 else "FAIL")
	return failures
