extends RefCounted
# Guardrail response scales with speed, and a car that ends up past the rail returns to the road.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	# 투어와 트랙은 같은 실제 장벽 접촉을 사용한다.
	r.choose_mode("tour")
	await tree.physics_frame
	var world_checks := preload("res://tests/world_crash_checks.gd").new()
	await world_checks.rail_impact(tree,r,40)
	await world_checks.rail_impact(tree,r,72)
	failures += world_checks.failures
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
	# Launch speed gates the throw; faster hits fly higher, longer and tumble more.
	var Crash = preload("res://scripts/physics/crash_state.gd")
	check(not Crash.launches(Crash.LAUNCH_SPEED,Crash.LAUNCH_SPEED) and Crash.launches(Crash.LAUNCH_SPEED+1,Crash.LAUNCH_SPEED+1) and not Crash.launches(80,40),"200km/h 이하 또는30도 이하는 벽 충돌 비행 금지")
	var tiers := []
	for incoming in [46.0,60.0,75.0,95.0]:
		var c = Crash.new()
		c.start(incoming,Vector2(1,0),0.0,2.0*Crash.launch_up(incoming)/24.0)
		tiers.append({"up":Crash.launch_up(incoming),"duration":c.duration,"rolls":c.rolls,"flips":c.flips})
	for i in range(1,tiers.size()):
		check(tiers[i].up > tiers[i-1].up and tiers[i].duration >= tiers[i-1].duration and tiers[i].rolls >= tiers[i-1].rolls and tiers[i].flips >= tiers[i-1].flips,"A faster hit must fly higher, hang longer and tumble at least as much")
	check(tiers[0].flips == 0 and tiers[3].flips >= 2 and tiers[3].rolls >= 3,"The fastest hits must flip over, the slowest launches only roll")
	var tumble = Crash.new()
	tumble.start(95.0,Vector2(1,0),0.0,1.6)
	tumble.advance(tumble.duration*0.5)
	check(absf(tumble.visual_pitch) > PI and absf(tumble.visual_roll) > PI*2,"A top-speed tumble must be visibly flipping mid-air")
	check(tumble.advance(tumble.duration) and tumble.visual_roll == 0 and tumble.visual_pitch == 0,"The tumble must finish upright")
	# After a rail hit the nose eases toward the road, but only part of the way.
	var car = world.player_body
	car.road_heading = Vector3.FORWARD
	car.surface_normal = Vector3.UP
	var turned: Vector3 = Vector3.FORWARD.rotated(Vector3.UP,0.5)
	car.realign_time = car.REALIGN_TIME
	var eased: Vector3 = car.realigned(turned,1.0/60)
	var before := absf(turned.signed_angle_to(Vector3.FORWARD,Vector3.UP))
	var after := absf(eased.signed_angle_to(Vector3.FORWARD,Vector3.UP))
	check(after < before and after > before*0.8,"A rail hit must ease the nose toward the road without snapping it straight")
	car.road_heading = Vector3.BACK
	check(car.realigned(turned,1.0/60).is_equal_approx(turned),"A car facing against the road must not be spun around")
	r.queue_free()
	await tree.process_frame
	print("Guardrail response scales with speed / spin / freeze-frame / return to road: ","PASS" if failures == 0 else "FAIL")
	return failures
