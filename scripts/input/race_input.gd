extends RefCounted
# 키보드·게임패드·터치 입력을 화면 상태에 맞는 동작으로 연결한다. 동작 자체는 race.gd와 hud.gd가 수행한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Pad = preload("res://scripts/input/gamepad_input.gd")
# 설정 화면에서 패드로 고를 수 있는 줄 수.
const SETTINGS_ROWS := 8
var race: Node3D


func _init(owner: Node3D) -> void:
	race = owner


func handle(event: InputEvent) -> void:
	if Pad.is_pad_event(event):
		# State is always tracked, so a button released during a transition cannot stick.
		if race.pad.handle(event):
			race.gamepad_active = true
		var blocked: bool = (race.screen_transition != null and race.screen_transition.busy) or race.shell.portrait
		if event is InputEventJoypadButton and event.pressed and not blocked:
			pad_pressed(event.button_index)
		return
	if (event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		race.gamepad_active = false
	if race.screen_transition != null and race.screen_transition.busy:
		return
	if race.shell.portrait:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if race.passport_open:
			if event.keycode in [KEY_ESCAPE, KEY_P, KEY_ENTER]:
				race.toggle_passport()
			return
		if race.state == RaceState.MENU:
			if event.keycode in [KEY_ENTER, KEY_1, KEY_T]:
				race.navigate_to_mode("tour")
			elif event.keycode in [KEY_2, KEY_C]:
				race.navigate(race.open_courses)
			elif event.keycode == KEY_P:
				race.toggle_passport()
			elif event.keycode == KEY_TAB:
				race.navigate(race.open_settings)
			return
		if race.state == RaceState.COURSES:
			if event.keycode in [KEY_1, KEY_ENTER]:
				race.navigate_to_mode("track", 0)
			elif event.keycode == KEY_2:
				race.navigate_to_mode("track", 1)
			elif event.keycode == KEY_3:
				race.navigate_to_mode("track", 2)
			elif event.keycode == KEY_4:
				race.navigate_to_mode("track", 3)
			elif event.keycode == KEY_5:
				race.navigate_to_mode("track", 4)
			elif event.keycode == KEY_ESCAPE:
				race.navigate(race.open_menu)
			return
		if race.state == RaceState.SETTINGS:
			if event.keycode in [KEY_ESCAPE, KEY_TAB]:
				race.navigate(race.close_settings)
			return
		if race.state == RaceState.READY and event.keycode == KEY_ESCAPE:
			if race.mode == "track":
				race.navigate(race.open_courses)
			else:
				race.navigate(race.open_menu)
			return
		if event.keycode == KEY_ENTER:
			if race.state == RaceState.READY:
				race.start_race()
			elif race.state in RaceState.ENDED:
				race.navigate(race.open_garage)
		elif race.state == RaceState.READY and event.keycode >= KEY_1 and event.keycode < KEY_1 + Catalog.SPECS.size():
			race.select_vehicle(event.keycode - KEY_1)
		elif race.state == RaceState.READY and event.keycode in [KEY_A, KEY_LEFT]:
			race.select_vehicle(posmod(race.selected_vehicle - 1, Catalog.SPECS.size()))
		elif race.state == RaceState.READY and event.keycode in [KEY_D, KEY_RIGHT]:
			race.select_vehicle((race.selected_vehicle + 1) % Catalog.SPECS.size())
		elif race.state == RaceState.READY and event.keycode in [KEY_C, KEY_N]:
			race.cycle_cosmetic(event.keycode == KEY_N)
		elif race.state == RaceState.READY and event.keycode == KEY_G:
			race.toggle_ghost()
		elif event.keycode == KEY_V:
			race.toggle_sound()
		elif event.keycode == KEY_M:
			race.toggle_motion()
		elif event.keycode == KEY_R and race.state != RaceState.READY:
			race.start_race()
		elif event.keycode == KEY_G and race.state == RaceState.PAUSED:
			race.navigate(race.open_menu)
		elif event.keycode in [KEY_ESCAPE, KEY_P]:
			if race.state == RaceState.PAUSED:
				race.resume_tour()
			else:
				race.pause_tour()
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		race.hud.handle_pointer(event)
	if event is InputEventScreenDrag:
		race.hud.move_pointer(event.index, event.position)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		race.hud.move_pointer(-1, event.position)


# A pad button press, mapped like the keyboard shortcuts of the same screen.
func pad_pressed(button: int) -> void:
	if race.passport_open:
		if button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_BACK, JOY_BUTTON_LEFT_SHOULDER]:
			race.toggle_passport()
		return
	var count := Catalog.SPECS.size()
	match race.state:
		RaceState.MENU:
			match button:
				JOY_BUTTON_LEFT_SHOULDER:
					race.toggle_passport()
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
					pad_focus(button)
				JOY_BUTTON_A:
					match race.menu_focus:
						0:
							race.navigate_to_mode("tour")
						1:
							race.navigate(race.open_courses)
						_:
							race.navigate(race.open_settings)
				JOY_BUTTON_X:
					race.navigate(race.open_courses)
				JOY_BUTTON_Y:
					race.navigate(race.open_settings)
		RaceState.COURSES:
			match button:
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
					pad_focus(button)
				JOY_BUTTON_A:
					match race.menu_focus:
						0, 1, 2, 3, 4:
							race.navigate_to_mode("track", race.menu_focus)
						_:
							race.navigate(race.open_menu)
				JOY_BUTTON_X:
					race.navigate_to_mode("track", 1)
				JOY_BUTTON_Y:
					race.navigate_to_mode("track", 2)
				JOY_BUTTON_B:
					race.navigate(race.open_menu)
		RaceState.SETTINGS:
			match button:
				JOY_BUTTON_DPAD_UP:
					race.settings_focus = posmod(race.settings_focus - 1, SETTINGS_ROWS)
				JOY_BUTTON_DPAD_DOWN:
					race.settings_focus = posmod(race.settings_focus + 1, SETTINGS_ROWS)
				JOY_BUTTON_A:
					settings_activate(race.settings_focus)
				JOY_BUTTON_B, JOY_BUTTON_START:
					race.navigate(race.close_settings)
		RaceState.READY:
			match button:
				JOY_BUTTON_X:
					race.cycle_cosmetic()
				JOY_BUTTON_BACK:
					race.cycle_cosmetic(true)
				JOY_BUTTON_Y:
					race.toggle_ghost()
				JOY_BUTTON_A, JOY_BUTTON_START:
					race.start_race()
				JOY_BUTTON_B:
					race.navigate(race.open_courses if race.mode == "track" else race.open_menu)
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
					race.select_vehicle(posmod(race.selected_vehicle - 1, count))
				JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
					race.select_vehicle((race.selected_vehicle + 1) % count)
		RaceState.RACING, RaceState.COUNTDOWN:
			match button:
				JOY_BUTTON_START, JOY_BUTTON_BACK:
					race.pause_tour()
				JOY_BUTTON_Y:
					race.recover_car()
				JOY_BUTTON_LEFT_SHOULDER:
					race.select_route(0)
				JOY_BUTTON_RIGHT_SHOULDER:
					race.select_route(1)
		RaceState.PAUSED:
			match button:
				JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK:
					race.resume_tour()
				JOY_BUTTON_X:
					race.navigate(race.open_menu)
				JOY_BUTTON_Y:
					race.start_race()
		RaceState.FINISHED, RaceState.FAILED:
			match button:
				JOY_BUTTON_A:
					race.navigate(race.open_garage)
				JOY_BUTTON_X, JOY_BUTTON_BACK:
					race.start_race()


# D-pad (or the left stick, see pad_stick_navigation) moves the gold focus frame: left/right
# between the two cards, up to the corner button, down back to the last card.
func pad_focus(button: int) -> void:
	# The home screen has two cards, the circuit screen three; the corner button comes after them.
	var cards: int = race.COURSE_COUNT if race.state == RaceState.COURSES else 2
	match button:
		JOY_BUTTON_DPAD_LEFT:
			if race.menu_focus > 0 and race.menu_focus < cards:
				race.menu_focus -= 1
		JOY_BUTTON_DPAD_RIGHT:
			if race.menu_focus < cards - 1:
				race.menu_focus += 1
		JOY_BUTTON_DPAD_UP:
			if race.menu_focus != cards:
				race.menu_last_card = race.menu_focus
				race.menu_focus = cards
		JOY_BUTTON_DPAD_DOWN:
			if race.menu_focus == cards:
				race.menu_focus = race.menu_last_card


# The left stick drives every menu like the D-pad, with a short repeat while held.
func pad_stick_navigation(delta: float) -> void:
	if race.state not in RaceState.MENUS or (race.screen_transition != null and race.screen_transition.busy):
		race.nav_dir = ""
		return
	var x: float = race.pad.axis(JOY_AXIS_LEFT_X)
	var y: float = race.pad.axis(JOY_AXIS_LEFT_Y)
	var wanted := ""
	if absf(x) > 0.6 and absf(x) >= absf(y):
		wanted = "right" if x > 0 else "left"
	elif absf(y) > 0.6:
		wanted = "down" if y > 0 else "up"
	if wanted == "":
		race.nav_dir = ""
		race.nav_wait = 0
		return
	race.nav_wait -= delta
	if wanted == race.nav_dir and race.nav_wait > 0:
		return
	var first: bool = wanted != race.nav_dir
	race.nav_dir = wanted
	race.nav_wait = 0.4 if first else 0.17
	race.gamepad_active = true
	pad_pressed(
		{
			"left": JOY_BUTTON_DPAD_LEFT,
			"right": JOY_BUTTON_DPAD_RIGHT,
			"up": JOY_BUTTON_DPAD_UP,
			"down": JOY_BUTTON_DPAD_DOWN
		}[wanted]
	)


func settings_activate(index: int) -> void:
	match index:
		0:
			race.toggle_sound()
		1:
			race.toggle_motion()
		2:
			race.cycle_graphics()
		3:
			race.toggle_fps()
		4:
			race.toggle_auto_accelerate()
		5:
			race.shell.toggle_fullscreen()
		6:
			race.hud.install_game()
		_:
			race.navigate(race.close_settings)
