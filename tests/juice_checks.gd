extends RefCounted
# Driving juice: gamepad/phone haptics, rail scrape rumble and kerb shake.
const Haptics = preload("res://scripts/haptics.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)

func run(tree: SceneTree) -> int:
	# A stronger pulse may cut a weaker one short; a weaker one may not cut a stronger.
	var h := Haptics.new()
	check(h.pulse(0.5,0.5,0.3,2),"A pulse on an idle pad must play")
	check(not h.pulse(0.2,0.2,0.1,1),"A weaker pulse must not interrupt a stronger one")
	check(h.pulse(1.0,1.0,0.4,3),"A stronger pulse must interrupt a weaker one")
	h.enabled = false
	check(not h.pulse(1,1,0.4,4),"Disabled haptics must stay silent")
	var r = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(r)
	r.set_physics_process(false)
	r.save_records = false
	r.choose_mode("tour")
	await tree.physics_frame
	r.restart()
	r.state = "racing"
	for rival in r.rivals: rival.active = false
	# A hard hit rumbles the pad; reduced motion turns every pulse off.
	r.haptics.busy_until = 0
	var before: int = r.haptics.pulses
	r.bump_cooldown = 0
	r.register_impact(0.8,Vector2(1,0))
	check(r.haptics.pulses > before,"A hard impact must rumble")
	r.motion_reduced = true
	r.step(1.0/60,0,false,true,false)
	check(not r.haptics.enabled,"Reduced motion must switch haptics off")
	r.motion_reduced = false
	# Grinding along the rail rumbles, shakes the camera and keeps going at a fixed pace.
	r.restart()
	r.state = "racing"
	for rival in r.rivals: rival.active = false
	r.distance = 400
	r.speed = 40
	r.lane = r.track.lane_limits(r.distance).y-0.05
	r.lane_velocity = 0
	r.haptics.busy_until = 0
	before = r.haptics.pulses
	r.step(1.0/60,0,false,true,false)
	check(r.edge_rumble >= 0.99 and r.haptics.pulses > before,"Scraping a rail must rumble and shake")
	var rumble: float = r.edge_rumble
	r.lane = 0.0
	r.speed = 40
	for frame in range(90): r.step(1.0/60,0,false,true,false)
	check(r.edge_rumble < 0.05 and rumble > 0.5,"The rumble must fade once the car is back in the middle of the road")
	# Kerb rumble is gentler than a rail scrape.
	r.lane = r.track.lane_limits(r.distance).y-0.8
	r.speed = 40
	r.step(1.0/60,0,false,true,false)
	check(r.edge_rumble >= 0.45 and r.edge_rumble < 0.99,"The kerb must shake less than a rail scrape")
	r.queue_free()
	await tree.process_frame
	print("Haptics priority / impact rumble / rail scrape / kerb shake: ","PASS" if failures == 0 else "FAIL")
	return failures
