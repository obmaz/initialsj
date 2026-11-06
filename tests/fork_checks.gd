extends RefCounted
const Report = preload("res://tests/report.gd")
const Library = preload("res://scripts/route_library.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var rows := []
	for stage in range(4):
		for node in range(stage+1):
			race.track.reset(stage,node)
			var arrows: MeshInstance3D = race.track.active.get_node("ForkRoadArrows")
			check(arrows.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].y > 0.8,"Fork direction paint must face upward and remain visible")
			var max_bend := 0.0
			var gate: float = race.track.active.checkpoint_distance()
			for sample in range(30):
				max_bend = maxf(max_bend,absf(race.track.curvature(lerpf(gate+20,race.track.length-15,sample/29.0))))
			check(max_bend < 0.0001,"Every route must remain straight between its checkpoint and fork")
			rows.append({"stage":stage,"node":node,"straight_m":race.track.length-gate,"maximum_curvature":max_bend})
	var fastest := 0.0
	for index in range(3):
		var v := Catalog.spec(index)
		fastest = maxf(fastest,maxf(v.overdrive_speed+2,v.max_speed+21))
	check(Library.CHECKPOINT_RUNUP/(fastest*race.GAME_PACE) >= 5,"Even the fastest boost must leave at least five real seconds before the split")
	race.track.reset()
	race.restart()
	race.state = "racing"
	for r in race.rivals: r.active = false
	race.distance = race.track.active.checkpoint_distance()-0.5
	race.speed = 65
	for frame in range(4): race.step(1.0/60,0,false,true,false)
	check(race.checkpoints == 1 and race.stage_index == 0 and race.route_choices_visible(),"Checkpoint must award time and expose route choices before changing stage")
	var checkpoint_time: float = race.time_left
	for frame in range(300):
		race.speed = fastest
		race.step(race.GAME_PACE/60,0,false,false,false)
	check(race.stage_index == 0 and race.distance < race.track.length,"Five real seconds after checkpoint must still be a straight road")
	check(race.checkpoints == 1 and race.time_left < checkpoint_time,"The straight approach must not award a checkpoint twice")
	for index in range(3):
		for side in [0,1]:
			race.open_garage()
			race.select_vehicle(index)
			race.restart()
			race.state = "racing"
			for r in race.rivals: r.active = false
			race.award_checkpoint()
			race.distance = race.track.length-165
			race.lane = 3.5 if side == 0 else -3.5
			race.speed = 65
			race.hud.fingers[1] = race.hud.buttons.gas.get_center()
			var tap := InputEventScreenTouch.new()
			tap.index = 7
			tap.pressed = true
			var rect: Rect2 = race.hud.ROUTE_LEFT if side == 0 else race.hud.ROUTE_RIGHT
			tap.position = rect.get_center()*race.hud.ui_scale()+race.hud.ui_offset()
			race.hud.handle_pointer(tap)
			check(race.route_preference == side,"Large route cards must select the intended side by touch")
			tap.pressed = false
			race.hud.handle_pointer(tap)
			check(race.hud.held("gas") and not race.hud.fingers.has(7),"Choosing a route with a second finger must preserve the held gas control")
			var last: Vector3 = race.track.point(race.distance,race.lane)
			var max_step := 0.0
			for frame in range(600):
				race.step(1.0/60,0,false,true,false)
				var world: Vector3 = race.track.point(race.distance,race.lane)
				max_step = maxf(max_step,world.distance_to(last))
				last = world
				if race.stage_index == 1: break
			check(race.stage_index == 1 and race.route_node == side,"Touch choice must steer each vehicle into the chosen physical branch")
			check(race.wall_hits == 0 and max_step < 2.5,"Route assistance must stay inside bounds without teleporting")
			check(race.checkpoints == 1 and not race.route_choices_visible(),"Branch commitment must hide the cards without a second checkpoint")
	race.open_garage()
	race.state = "racing"
	race.award_checkpoint()
	race.distance = race.track.length-100
	race.select_route(1)
	check(is_equal_approx(race.route_axis(-0.8),-0.8) and race.route_preference == -1,"Manual steering must override optional route assistance immediately")
	FileAccess.open(Report.path("fork-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"straight_routes":rows,"minimum_real_seconds_at_fastest_boost":Library.CHECKPOINT_RUNUP/(fastest*race.GAME_PACE),"failures":failures},"\t")+"\n")
	print("Checkpoint / straight approach / mobile route choice / manual override: ","PASS" if failures == 0 else "FAIL")
	race.queue_free()
	await tree.process_frame
	return failures
