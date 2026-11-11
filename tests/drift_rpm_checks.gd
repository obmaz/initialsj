extends RefCounted
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func step(race: Node3D, drift: bool, axis: float = 0.6, brake: bool = false) -> void:
	# 차체를 움직이지 않고 입력 상태 전이만 검사한다.
	race.step(0.05,axis,drift,true,brake)
func touch(race: Node3D, action: String, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = race.hud.buttons[action].get_center()*race.hud.ui_scale()+race.hud.ui_offset()
	race.hud.handle_pointer(event)

func run(tree: SceneTree) -> int:
	var race=load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	preload("res://tests/tour_world_checks.gd").new().set_car(race,80,0,55)
	step(race,true,0)
	check(race.drift_pending > 0 and not race.drifting,"A drift tap before steering must briefly arm entry")
	step(race,false)
	check(race.drifting,"Steering shortly after a tap must enter the chosen drift")
	step(race,true)
	check(not race.drifting and race.drift_pending == 0,"A second tap must end drift immediately")
	for frame in range(8): step(race,true)
	check(not race.drifting,"Holding the end tap must not repeatedly restart a drift")
	step(race,false,-1)
	step(race,false,-1)
	step(race,true,-1)
	check(race.drifting and race.drift_sign == -1,"A fresh tap must immediately allow a drift in the opposite direction")
	for frame in range(8): step(race,true,-1)
	check(race.drifting,"Holding an entry tap must not toggle the drift off each frame")
	step(race,false,-1,true)
	check(race.drifting,"Braking with steering must keep a controlled corner drift")
	for frame in range(8): step(race,false,0,true)
	check(not race.drifting,"Braking with unwound steering must settle the drift")
	race.restart()
	race.state = "racing"
	for rival in race.rivals: rival.active = false
	preload("res://tests/tour_world_checks.gd").new().set_car(race,80,0,50)
	touch(race,"right",11,true)
	touch(race,"drift",12,true)
	for frame in range(4): race.step(0.05,race.hud.touch_axis(),race.hud.held("drift"),true,false)
	check(race.drifting,"A real steering touch and drift-button press must enter the drift")
	touch(race,"drift",12,false)
	check(not race.hud.held("drift"),"Releasing the drift finger must clear its held input")
	race.step(0.05,race.hud.touch_axis(),race.hud.held("drift"),true,false)
	touch(race,"drift",12,true)
	race.step(0.05,race.hud.touch_axis(),race.hud.held("drift"),true,false)
	check(not race.drifting,"The next touch tap must end drift without a cooldown")
	touch(race,"drift",12,false)
	touch(race,"right",11,false)
	check(race.hud.fingers.is_empty(),"All released touches must leave no held steering input")
	for index in range(preload("res://scripts/vehicles/vehicle_catalog.gd").SPECS.size()):
		race.open_garage()
		race.select_vehicle(index)
		race.restart()
		race.state = "racing"
		race.speed = 0
		check(race.gear_number() == 0 and race.engine_rpm() >= 850,"A stopped car must show neutral and idle RPM")
		var band: float = race.vehicle.max_speed/5.8
		race.speed = band*0.99
		var before: float = race.engine_rpm()
		race.speed = band*1.01
		check(race.gear_number() == 2 and race.engine_rpm() < before,"Automatic shifts must drop the displayed and audible RPM together")
		race.speed = race.vehicle.boost_speed
		check(race.gear_number() == 6 and race.engine_rpm() > 6500 and race.engine_rpm() <= 7500,"Boost must fill the RPM bar into its bounded redline")
	print("Drift toggle / RPM checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await tree.process_frame
	return failures
