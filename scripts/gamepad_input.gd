extends RefCounted
# Standard racing-pad layout (Xbox naming; Godot maps PlayStation and Switch pads to the same
# buttons). State is tracked from the pad's own events, so it behaves the same in the browser
# (Gamepad API) and natively, and tests can drive it with synthetic events.
#
#   RT gas            LT brake / reverse        Left stick, D-pad left/right  steer
#   A nitro           X drift (tap to end)      B overdrive cell (Ironvale)
#   Y reset car       LB / RB  tour route left / right
#   Start pause       Back  restart             Menus: A confirm, B back, X / Y alternates
const DEADZONE := 0.16
const TRIGGER_ON := 0.25
const ACTIVE_AXIS := 0.45
var axes := {}
var buttons := {}
var layout := "xbox"

static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func clear() -> void:
	axes.clear()
	buttons.clear()

# Returns true when the event means the player is using the pad right now.
func handle(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		axes[event.axis] = event.axis_value
		if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]: return absf(event.axis_value) >= ACTIVE_AXIS
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]: return event.axis_value > TRIGGER_ON
		return false
	if event is InputEventJoypadButton:
		buttons[event.button_index] = event.pressed
		if event.pressed: layout = layout_for(Input.get_joy_name(event.device))
		return event.pressed
	return false

static func layout_for(joy_name: String) -> String:
	var lowered := joy_name.to_lower()
	for key in ["ps3","ps4","ps5","dualshock","dualsense","playstation","sony"]:
		if lowered.contains(key): return "playstation"
	return "xbox"

func held(button: int) -> bool:
	return bool(buttons.get(button,false))

func axis(index: int) -> float:
	return float(axes.get(index,0.0))

# Left stick with a radial-friendly dead zone, rescaled so the edge of the zone is 0 and full tilt 1.
func steer() -> float:
	var x := axis(JOY_AXIS_LEFT_X)
	var value := 0.0
	if absf(x) > DEADZONE: value = signf(x)*(absf(x)-DEADZONE)/(1.0-DEADZONE)
	value += float(held(JOY_BUTTON_DPAD_RIGHT))-float(held(JOY_BUTTON_DPAD_LEFT))
	return clampf(value,-1,1)

func gas() -> bool:
	return axis(JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_ON

func brake() -> bool:
	return axis(JOY_AXIS_TRIGGER_LEFT) > TRIGGER_ON

func nitro() -> bool:
	return held(JOY_BUTTON_A)

func drift() -> bool:
	return held(JOY_BUTTON_X)

func cell() -> bool:
	return held(JOY_BUTTON_B)

# On-screen names of the pad's buttons for the current layout.
func label(action: String) -> String:
	if layout == "playstation":
		match action:
			"gas": return "R2"
			"brake": return "L2"
			"nitro": return "CROSS"
			"drift": return "SQUARE"
			"cell": return "CIRCLE"
			"reset": return "TRIANGLE"
			"pause": return "OPTIONS"
			"restart": return "SHARE"
			"confirm": return "CROSS"
			"back": return "CIRCLE"
			"alt": return "SQUARE"
			"alt2": return "TRIANGLE"
			"route_left": return "L1"
			"route_right": return "R1"
	else:
		match action:
			"gas": return "RT"
			"brake": return "LT"
			"nitro": return "A"
			"drift": return "X"
			"cell": return "B"
			"reset": return "Y"
			"pause": return "START"
			"restart": return "BACK"
			"confirm": return "A"
			"back": return "B"
			"alt": return "X"
			"alt2": return "Y"
			"route_left": return "LB"
			"route_right": return "RB"
	match action:
		"steer": return "L-STICK"
		"dpad": return "D-PAD"
		"shoulders": return "L1 / R1" if layout == "playstation" else "LB / RB"
	return ""
