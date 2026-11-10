extends RefCounted
const Report = preload("res://tests/report.gd")
const Air = preload("res://tests/flight_envelope_model.gd")
const Surface = preload("res://scripts/road_surface_state.gd")
class GradeRoad:
	extends Node3D
	var length := 2000.0
	var closed_loop := false
	var grade := 0.0
	var features: Array[Dictionary] = [{"kind":"ramp","id":"grade-ramp","distance":100.0,"lane":0.0,"length":16.0,"width":3.8,"height":0.75}]
	func point(d: float, lane: float = 0.0) -> Vector3:
		return Vector3(lane,d*grade,-d)
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func grade_regressions() -> Array:
	var rows := []
	for grade in [-0.16,0.0,0.16]:
		var road := GradeRoad.new()
		road.grade = grade
		var ramp: Dictionary = road.features[0]
		var edge: float = ramp.distance+ramp.length*0.5
		for speed in [20.0,65.0,112.0]:
			for dt in [1.0/120,1.0/30,0.2]:
				var air := Air.new()
				var pos := Vector2(0,ramp.distance-ramp.length)
				var peak := 0.0
				var launch_at := -1.0
				var land_at := -1.0
				var launches := 0
				var landings := 0
				for frame in range(ceili(2.0/dt)):
					var to := pos+Vector2(0,speed*dt)
					for event in air.advance(road,pos,to,speed,dt):
						if event == "launch":
							launch_at = frame*dt+(edge-pos.y)/speed
							launches += 1
						if event == "land":
							land_at = (frame+1)*dt
							landings += 1
					peak = maxf(peak,air.height)
					pos = to
				var duration := land_at-launch_at
				check(launches == 1 and landings == 1 and not air.active,"Every supported grade/speed/frame step must launch and land exactly once")
				check(duration >= 0.5 and duration < 0.82,"A road-space jump must remain brief on both uphill and downhill roads, including coarse frames")
				check(peak > 0.9 and peak < 2.0,"The shorter jump must retain a visible, bounded peak")
				check(peak+1.35 < 4.5,"Even the fastest supported ramp must leave chassis clearance beneath a tunnel ceiling")
				rows.append({"grade":grade,"speed_mps":speed,"step":dt,"airtime_seconds_upper_bound":duration,"peak_m":peak})
		var slow := Air.new()
		var slow_events := slow.advance(road,Vector2(0,edge-0.05),Vector2(0,edge+0.05),5,0.02)
		check(not slow_events.has("launch") and not slow.trick and slow.velocity <= 0,"Slow roll-off must not gain an upward impulse on either road grade")
		road.free()
	return rows
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var report := []
	var grades := grade_regressions()
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
			var launch_at := -1.0
			var land_at := -1.0
			for frame in range(int(3.0/dt)):
				var to := pos+Vector2(0,speed*dt)
				for event in air.advance(section,pos,to,speed,dt):
					if event == "launch":
						launched += 1
						launch_at = frame*dt+(ramp.distance+ramp.length*0.5-pos.y)/speed
					if event == "land":
						landed += 1
						land_at = (frame+1)*dt
				peak = maxf(peak,air.height)
				check(air.height >= 0,"A jumping car must not penetrate the road")
				pos = to
			check(launched == 1 and landed == 1 and not air.active,"Every ramp crossing must produce one launch and one landing at varied frame steps")
			check(peak > 0.9 and peak < 2.2,"A fast ramp must produce a visible, bounded jump")
			check(land_at-launch_at >= 0.4 and land_at-launch_at < 0.85,"Authored road-space ramps must return the car to the road quickly")
			var edge: float = ramp.distance+ramp.length*0.5
			check(air.advance(section,Vector2(ramp.lane,edge-1),Vector2(ramp.lane,edge+1),65,dt).is_empty(),"Waiting or revisiting a ramp edge must not relaunch it in the same lap")
			report.append({"mode":choice[0],"course":choice[1],"step":dt,"peak_m":peak,"airtime_seconds_upper_bound":land_at-launch_at,"launches":launched,"landings":landed})
		var miss := Air.new()
		var from := Vector2(-ramp.lane,ramp.distance-ramp.length)
		check(miss.advance(section,from,from+Vector2(0,ramp.length*2),65,0.5).is_empty(),"The clear side of the road must avoid the ramp")
		var slow := Air.new()
		var drop := slow.advance(section,Vector2(ramp.lane,ramp.distance-20),Vector2(ramp.lane,ramp.distance+20),5,0.5)
		check(not drop.has("launch") and slow.velocity <= 0 and not slow.trick and slow.world_y <= section.point(ramp.distance+ramp.length*0.5,ramp.lane).y+ramp.height+0.001,"Slow cars must roll off under gravity without an artificial upward impulse")
		var surface := Surface.new()
		var from_ramp := Vector2(ramp.lane,ramp.distance-20)
		check(surface.contact(section,from_ramp,from_ramp+Vector2(0,40),65).is_empty() and surface.boosts_hit == 0,"A ramp must not accidentally act as a free nitro pad")
	# 실제 높이별 차체 접촉은 world_car_checks·world_rival_checks에서 검사한다.
	FileAccess.open(Report.path("jump-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"cases":report,"grade_speed_cases":grades,"failures":failures},"\t")+"\n")
	print("Ramp / shorter ballistic flight / road grade / landing / vertical collision checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
