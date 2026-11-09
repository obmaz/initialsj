extends RefCounted
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const Library = preload("res://scripts/route_library.gd")
var failures := 0
var race: Node3D
var root: Window
func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1
func drive(index: int) -> void:
	race.open_garage()
	race.select_vehicle(index)
	race.restart()
	race.state = "racing"
	for r in race.rivals: r.distance = 10000
	race.speed = 60
	race.lane = 0
func tick(held: bool, cell: bool = false, brake: bool = false) -> void:
	# Isolate nitro and acceleration from road curvature and traffic.
	preload("res://tests/tour_world_checks.gd").new().set_car(race,80,0,race.speed)
	race.step(1.0/60,0,false,true,brake,held,cell)
func click(p: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = p*race.hud.ui_scale()+race.hud.ui_offset()
	race.hud.handle_pointer(event)
	event.pressed = false
	race.hud.handle_pointer(event)
func run(tree: SceneTree) -> int:
	root = tree.root
	race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	await root.get_tree().process_frame
	# P2: a checkpoint and a finish reached after the deadline must not count.
	for stage in [0,4]:
		drive(0)
		race.track.reset(stage,0)
		race.distance = (race.track.active.checkpoint_distance() if stage == 0 else race.track.length)-0.2
		race.time_left = 0.001
		race.speed = 80
		race.step(1.0/60,0,false,true,false)
		check(race.state == "failed" and race.checkpoints == 0,"Deadline must stop movement before a late checkpoint or finish")
	# Reaching the line before the deadline remains legal.
	drive(0)
	preload("res://tests/tour_world_checks.gd").new().set_car(race,race.track.active.checkpoint_distance()-0.02,0,80)
	race.time_left = 0.001
	race.step(1.0/60,0,false,true,false)
	check(race.checkpoints == 1 and race.time_left > 50,"Checkpoint reached within remaining time must award time")
	# P2: focus loss pauses countdown and resumes the same phase.
	race.restart()
	race.countdown = 2
	race.hud.fingers[1] = race.hud.buttons.gas.get_center()
	race._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	race._physics_process(0.5)
	check(race.state == "paused" and race.countdown == 2 and race.hud.fingers.is_empty(),"Focus loss must freeze countdown and release touch inputs")
	race.resume_tour()
	race._physics_process(0.5)
	check(race.state == "countdown" and race.countdown == 1.5,"Resume must restore countdown rather than skip straight to racing")
	race.pause_tour()
	click(race.hud.buttons.pause.get_center())
	check(race.state == "countdown","TIME touch panel must also resume the saved countdown phase")
	# Portrait is a rotation notice, not an active driving layout.
	race.hud.fingers[7] = race.hud.buttons.gas.get_center()
	race._on_web_orientation([true])
	var frozen_countdown: float = race.countdown
	race._physics_process(0.5)
	race.resume_tour()
	check(race.state == "paused" and race.countdown == frozen_countdown and race.hud.fingers.is_empty(),"Portrait must pause the tour, release touches and block resume")
	race._on_web_orientation([false])
	check(race.state == "paused","Returning to landscape must wait for explicit resume")
	race.resume_tour()
	check(race.state == "countdown","Landscape resume must preserve the countdown phase")
	# Selection/touch hit regions in supported landscape viewports.
	for viewport in [Vector2i(1280,720),Vector2i(896,414),Vector2i(2340,1080)]:
		root.size = viewport
		race.open_garage()
		for i in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
			click(race.hud.garage_card(i).get_center())
			check(race.selected_vehicle == i and race.player.model == Catalog.spec(i).model,"Card selection must update the real player model on every viewport")
		click(race.hud.garage_card(2).get_center())
		click(race.hud.GARAGE_START.get_center())
		check(race.state == "countdown" and race.nitro_charges == 2,"Drive must start the selected hybrid car with fresh resources")
		race.select_vehicle(0)
		check(race.selected_vehicle == 2,"Vehicle changes must be blocked during a tour")
	root.size = Vector2i(1280,720)
	# Gauge: hold, release, lockout, and regeneration.
	drive(0)
	var initial: float = race.nitro
	for i in range(60): tick(true)
	check(race.nitro_active and is_equal_approx(initial-race.nitro,15),"Hatch gauge must consume 15 fuel per second while held")
	tick(false)
	check(not race.nitro_active,"Gauge boost must stop immediately on release")
	var depleted: float = race.nitro
	for i in range(60): tick(false)
	check(is_equal_approx(race.nitro-depleted,2.4),"Released gauge must regenerate slowly")
	# Charges: prepaid burst survives release, holding consumes exactly one.
	drive(1)
	for i in range(240): tick(true)
	check(race.nitro_charges == 2 and not race.nitro_active,"Holding a shot button must never consume a second shot")
	tick(false)
	tick(true)
	tick(false)
	check(race.nitro_charges == 1 and race.nitro_active,"A second tap must spend one shot and remain active after release")
	tick(false,false,true)
	check(not race.nitro_active and race.nitro_burst_left == 0 and race.nitro_charges == 1,"Braking must cancel a prepaid burst without refund")
	for i in range(2):
		for j in range(30): tick(false)
		tick(true)
		tick(false,false,true)
	check(race.nitro_charges == 0 and not race.nitro_active,"No shot may fire after all charges are spent")
	# A held launch request queues without wasting a charge at standstill.
	drive(1)
	race.speed = 0
	tick(true)
	check(race.nitro_charges == 3,"Nitro at standstill must wait for minimum activation speed")
	# Reduced launch force takes longer to reach the activation speed.
	for i in range(180):
		tick(true)
		if race.nitro_active: break
	check(race.nitro_charges == 2 and race.nitro_active,"Held launch request must start one shot once fast enough")
	# Hybrid: gauge and independent cell boost, no gauge drain during overdrive.
	drive(2)
	tick(true)
	check(race.nitro_active and race.nitro < 55 and race.nitro_charges == 2,"Hybrid base boost must use the gauge")
	var fuel: float = race.nitro
	tick(true,true)
	check(race.nitro_charges == 1 and race.nitro_burst_left > 1.5 and is_equal_approx(fuel,race.nitro),"Hybrid cell must fire overdrive without draining the gauge")
	for i in range(120): tick(false,true)
	check(race.nitro_charges == 1,"Holding cell must not automatically spend the next cell")
	# P3: impact must synchronously stop gameplay boost and feedback.
	tick(true,false)
	tick(false,true)
	race.boosting = true
	race.register_impact(0.8,Vector2.RIGHT)
	check(not race.nitro_active and not race.boosting and race.nitro_burst_left == 0,"Impact must clear boost, pending burst and feedback immediately")
	# Checkpoints restore one charge up to each car's own capacity.
	for i in [1,2]:
		drive(i)
		race.nitro_charges = 0
		race.award_checkpoint()
		check(race.nitro_charges == 1,"Checkpoint must replenish one shot or cell")
	# Distinct driving tuning is observable, not just descriptive UI.
	var acceleration := []
	var impact_speeds := []
	var rear_contact_speeds := []
	for i in range(preload("res://scripts/vehicle_catalog.gd").SPECS.size()):
		drive(i)
		race.speed = 0
		for j in range(60): tick(false)
		acceleration.append(race.speed)
		race.speed = 60
		race.lane = 100
		race.step(1.0/60,0,false,false,false)
		impact_speeds.append(race.speed)
		drive(i)
		var other: Dictionary = race.rivals[0]
		other.distance = race.distance+3.5
		other.lane = race.lane
		other.speed = 40.0
		var contact: Dictionary = race.contact_with(other)
		check(not contact.is_empty(),"Rear contact fixture must overlap actual car bounds")
		if not contact.is_empty(): race.resolve_contact(other,contact)
		rear_contact_speeds.append(race.speed)
		check(race.speed < 60,"Hitting slower traffic must reduce speed")
	check(acceleration[2] > acceleration[0] and acceleration[0] > acceleration[1],"Muscle, hatch, exotic must have different acceleration")
	check(is_equal_approx(impact_speeds[0],impact_speeds[1]) and is_equal_approx(impact_speeds[1],impact_speeds[2]),"All vehicles must share the same collision speed loss; armor is not a vehicle ability")
	check(is_equal_approx(rear_contact_speeds[0],rear_contact_speeds[1]) and is_equal_approx(rear_contact_speeds[1],rear_contact_speeds[2]),"Rear-end collision losses must also be identical across vehicles")
	check(Catalog.record_key(0) != Catalog.record_key(1) and Catalog.record_key(1) != Catalog.record_key(2),"Best times must have separate vehicle record keys")
	print("Garage / nitro / review regression checks: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	race.queue_free()
	await root.get_tree().process_frame
	return failures
