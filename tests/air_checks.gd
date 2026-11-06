extends RefCounted
const Air = preload("res://scripts/air_state.gd")
const Surface = preload("res://scripts/road_surface_state.gd")
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
	var report := []
	for choice in [["tour",0],["track",0],["track",1]]:
		race.choose_mode(choice[0],choice[1])
		var section: Node3D = race.track.active
		var ramp: Dictionary = section.features.filter(func(f): return f.kind == "ramp")[0]
		for dt in [1.0/120,1.0/30,0.2]:
			var air := Air.new()
			var pos := Vector2(ramp.lane,ramp.distance-ramp.length)
			var speed := 65.0
			var peak := 0.0
			var launched := 0
			var landed := 0
			for frame in range(int(3.0/dt)):
				var to := pos+Vector2(0,speed*dt)
				for event in air.advance(section,pos,to,speed,dt):
					if event == "launch": launched += 1
					if event == "land": landed += 1
				peak = maxf(peak,air.height)
				check(air.height >= 0,"A jumping car must not penetrate the road")
				pos = to
			check(launched == 1 and landed == 1 and not air.active,"Every ramp crossing must produce one launch and one landing at varied frame steps")
			check(peak > 0.9 and peak < 5,"A fast ramp must produce a visible, bounded jump")
			var edge: float = ramp.distance+ramp.length*0.5
			check(air.advance(section,Vector2(ramp.lane,edge-1),Vector2(ramp.lane,edge+1),65,dt).is_empty(),"Waiting or revisiting a ramp edge must not relaunch it in the same lap")
			report.append({"mode":choice[0],"course":choice[1],"step":dt,"peak_m":peak,"launches":launched,"landings":landed})
		var miss := Air.new()
		var from := Vector2(-ramp.lane,ramp.distance-ramp.length)
		check(miss.advance(section,from,from+Vector2(0,ramp.length*2),65,0.5).is_empty(),"The clear side of the road must avoid the ramp")
		var slow := Air.new()
		var drop := slow.advance(section,Vector2(ramp.lane,ramp.distance-20),Vector2(ramp.lane,ramp.distance+20),5,0.5)
		check(not drop.has("launch") and slow.velocity <= 0 and not slow.trick and slow.world_y <= section.point(ramp.distance+ramp.length*0.5,ramp.lane).y+ramp.height+0.001,"Slow cars must roll off under gravity without an artificial upward impulse")
		var surface := Surface.new()
		var from_ramp := Vector2(ramp.lane,ramp.distance-20)
		check(surface.contact(section,from_ramp,from_ramp+Vector2(0,40),65).is_empty() and surface.boosts_hit == 0,"A ramp must not accidentally act as a free nitro pad")
	# Airborne vertical clearance must govern the real step collision path as well
	# as the contact helper. Cars at the same height must still collide.
	race.choose_mode("track",0)
	race.restart()
	race.state = "racing"
	for r in race.rivals: r.active = false
	var other: Dictionary = race.rivals[0]
	other.active = true
	other.distance = 82.5
	other.lane = race.lane
	other.speed = 0
	other.pace = 0
	race.speed = 45
	race.air.active = true
	race.air.height = 3.5
	race.air.world_y = race.track.point(race.distance).y+3.5
	race.air.velocity = 1
	check(race.contact_with(other).is_empty(),"A car several metres overhead must clear traffic")
	race.step(1.0/60,0,false,false,false)
	check(race.traffic_hits == 0,"The actual driving step must not apply a ground collision while jumping overhead")
	race.air.height = 0
	race.air.active = false
	other.distance = race.distance+2.5
	check(not race.contact_with(other).is_empty(),"Ground-level contact must remain active after landing")
	FileAccess.open("res://docs/jump-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"failures":failures},"\t")+"\n")
	print("Ramp / ballistic flight / landing / vertical collision checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
