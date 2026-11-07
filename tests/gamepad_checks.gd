extends RefCounted
# Standard racing-pad support: synthetic pad events go through the real _input path.
const Pad = preload("res://scripts/gamepad_input.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
class BusyTransition extends CanvasLayer:
	var busy := true
var failures := 0
var race: Node3D
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func button(index: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	race._input(event)
func tap(index: int) -> void:
	button(index,true)
	button(index,false)
func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	race._input(event)
func frames(count: int) -> void:
	for i in range(count): race._physics_process(1.0/60)
func drive() -> void:
	race.state = "racing"
	race.speed = 40
	race.lane = 0
	race.distance = 400
	for r in race.rivals: r.distance = 10000
func run(tree: SceneTree) -> int:
	race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var pad: RefCounted = race.pad
	# Stick dead zone and scaling, D-pad steering, trigger thresholds.
	axis(JOY_AXIS_LEFT_X,0.1)
	check(pad.steer() == 0.0,"Stick drift inside the dead zone must not steer")
	axis(JOY_AXIS_LEFT_X,0.58)
	check(pad.steer() > 0.4 and pad.steer() < 0.6,"Half stick tilt must give about half steering")
	axis(JOY_AXIS_LEFT_X,-1.0)
	check(is_equal_approx(pad.steer(),-1.0),"Full left tilt must steer fully left")
	axis(JOY_AXIS_LEFT_X,0.0)
	button(JOY_BUTTON_DPAD_RIGHT)
	check(is_equal_approx(pad.steer(),1.0),"D-pad right must steer right")
	button(JOY_BUTTON_DPAD_RIGHT,false)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.1)
	check(not pad.gas(),"A resting trigger must not be gas")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.9)
	check(pad.gas() and not pad.brake(),"The right trigger is gas")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	check(Pad.layout_for("Xbox Series X Controller") == "xbox" and Pad.layout_for("PS5 Controller") == "playstation" and Pad.layout_for("DualSense Wireless Controller") == "playstation","Pad names must pick the matching button labels")
	check(pad.label("nitro") == "A" and pad.label("drift") == "X" and pad.label("gas") == "RT","Xbox prompts: A nitro, X drift, RT gas")
	pad.layout = "playstation"
	check(pad.label("nitro") == "CROSS" and pad.label("drift") == "SQUARE" and pad.label("gas") == "R2","PlayStation prompts must use its own names")
	pad.layout = "xbox"
	# Using the pad shows its prompts; any keyboard, mouse or touch press hides them again.
	race.gamepad_active = false
	tap(JOY_BUTTON_START)
	check(race.gamepad_active,"A pad button press must switch the on-screen prompts to the pad")
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	race._input(key)
	check(not race.gamepad_active,"A key press must switch the prompts back")
	# Menus: A tour, X tracks, Y settings, B back.
	race.state = "menu"
	tap(JOY_BUTTON_X)
	check(race.state == "courses","Menu X must open the circuits")
	tap(JOY_BUTTON_B)
	check(race.state == "menu","Circuit B must go back")
	tap(JOY_BUTTON_Y)
	check(race.state == "settings","Menu Y must open settings")
	var sound: bool = race.sound_enabled
	tap(JOY_BUTTON_A)
	check(race.sound_enabled != sound and race.settings_focus == 0,"Settings A must change the focused row")
	race.sound_enabled = sound
	tap(JOY_BUTTON_DPAD_DOWN)
	tap(JOY_BUTTON_DPAD_DOWN)
	check(race.settings_focus == 2,"Settings D-pad must move the focus")
	tap(JOY_BUTTON_DPAD_UP)
	tap(JOY_BUTTON_DPAD_UP)
	tap(JOY_BUTTON_DPAD_UP)
	check(race.settings_focus == rows() - 1,"The settings focus must wrap")
	tap(JOY_BUTTON_B)
	check(race.state == "menu","Settings B must close")
	tap(JOY_BUTTON_A)
	check(race.state == "ready" and race.mode == "tour","Menu A must open the tour garage")
	# Garage: bumpers choose the car, A drives.
	race.select_vehicle(0)
	tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(race.selected_vehicle == 1,"RB must choose the next car")
	tap(JOY_BUTTON_LEFT_SHOULDER)
	tap(JOY_BUTTON_LEFT_SHOULDER)
	check(race.selected_vehicle == Catalog.SPECS.size()-1,"LB must wrap to the last car")
	race.select_vehicle(0)
	tap(JOY_BUTTON_A)
	check(race.state == "countdown","Garage A must start the race")
	# Driving: trigger gas, trigger brake, stick steering, A nitro, X drift.
	drive()
	race.step(1.0/60,0,false,false,false)
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	var before: float = race.speed
	frames(30)
	check(race.speed > before,"The right trigger must accelerate")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	var fast: float = race.speed
	frames(30)
	check(race.speed < fast-8,"The left trigger must brake much harder than coasting")
	axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	drive()
	axis(JOY_AXIS_LEFT_X,0.8)
	frames(20)
	check(race.steer > 0.3,"Stick right must steer right")
	axis(JOY_AXIS_LEFT_X,-0.8)
	frames(40)
	check(race.steer < -0.3,"Stick left must steer left")
	axis(JOY_AXIS_LEFT_X,0.0)
	button(JOY_BUTTON_A)
	frames(2)
	check(race.nitro_previous_input,"A must be the nitro input")
	button(JOY_BUTTON_A,false)
	button(JOY_BUTTON_X)
	frames(2)
	check(race.drift_previous_input,"X must be the drift input")
	button(JOY_BUTTON_X,false)
	frames(2)
	check(not race.nitro_previous_input and not race.drift_previous_input,"Releasing the buttons must release nitro and drift")
	# Start pauses, A resumes, a lost pad pauses and clears every input.
	tap(JOY_BUTTON_START)
	check(race.state == "paused","Start must pause the race")
	tap(JOY_BUTTON_A)
	check(race.state == "racing","A on the pause dialog must resume")
	axis(JOY_AXIS_LEFT_X,1.0)
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	button(JOY_BUTTON_A)
	race._on_joy_connection_changed(0,false)
	check(race.state == "paused" and pad.steer() == 0.0 and not pad.gas() and not pad.nitro(),"A pad that disconnects mid-race must pause and release every input")
	race.resume_tour()
	# A button released during a screen transition must not stay held.
	button(JOY_BUTTON_A)
	var transition := BusyTransition.new()
	race.screen_transition = transition
	button(JOY_BUTTON_A,false)
	check(not pad.nitro(),"A release during a transition must still be tracked")
	var state_before: String = race.state
	tap(JOY_BUTTON_START)
	check(race.state == state_before,"Pad presses must be ignored during a screen transition")
	race.screen_transition = null
	transition.free()
	# Results: A to the garage, X to retry.
	race.state = "finished"
	tap(JOY_BUTTON_A)
	check(race.state == "ready","Result A must return to the garage")
	race.queue_free()
	await tree.process_frame
	print("Gamepad / racing layout / menus / pause / disconnect / prompts: ","PASS" if failures == 0 else "FAIL")
	return failures
func rows() -> int:
	return race.SETTINGS_ROWS
