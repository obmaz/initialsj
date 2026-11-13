extends RefCounted
# 브라우저·창 셸과의 연결: 전체화면, 뒤로 가기, 화면 방향. 화면 전환 규칙은 race.gd가 결정한다.
const RaceState = preload("res://scripts/race/race_state.gd")
var diagnostics: RefCounted
var race: Node3D
var portrait := false
var orientation_callback: JavaScriptObject
var back_callback: JavaScriptObject
var fullscreen_callback: JavaScriptObject
var fullscreen_active := false
var dom_fullscreen_active := false
# 전체화면 종료 직후 같은 뒤로 가기 동작이 한 번 더 들어오는 시간.
var back_ignored_until := 0
var control_rect := Rect2()
var control_visible := false
var return_mode := DisplayServer.WINDOW_MODE_WINDOWED


func _init(owner: Node3D) -> void:
	race = owner


func attach() -> void:
	if not OS.has_feature("web"):
		return
	diagnostics = preload("res://scripts/platform/web_diagnostics.gd").new(race)
	diagnostics.attach()
	orientation_callback = JavaScriptBridge.create_callback(on_orientation)
	JavaScriptBridge.get_interface("window").initialsjObserveOrientation(orientation_callback)
	back_callback = JavaScriptBridge.create_callback(on_back)
	JavaScriptBridge.get_interface("window").initialsjObserveBack(back_callback, race.state != RaceState.MENU)
	fullscreen_callback = JavaScriptBridge.create_callback(on_fullscreen)
	JavaScriptBridge.get_interface("window").initialsjObserveFullscreen(fullscreen_callback)


func detach() -> void:
	if diagnostics != null:
		diagnostics.detach()
		diagnostics = null
	hide_control()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.get_interface("window").initialsjObserveOrientation(null)
	JavaScriptBridge.get_interface("window").initialsjObserveBack(null, false)
	JavaScriptBridge.get_interface("window").initialsjObserveFullscreen(null)
	back_callback = null
	fullscreen_callback = null


func on_fullscreen(args: Array) -> void:
	var active: bool = bool(args[0])
	var dom_active: bool = bool(args[1])
	var exited: bool = (fullscreen_active and not active) or (dom_fullscreen_active and not dom_active)
	fullscreen_active = active
	dom_fullscreen_active = dom_active
	# Android Back can leave browser fullscreen before dispatching popstate.
	if exited and race.state in [RaceState.RACING, RaceState.COUNTDOWN, RaceState.PAUSED]:
		race.pause_tour()
		# Some browser versions emit both fullscreenchange and popstate for
		# one Back gesture; do not let the second event immediately resume.
		back_ignored_until = Time.get_ticks_msec() + 350


func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("window.initialsjIsFullscreen && window.initialsjIsFullscreen()"))
	if DisplayServer.get_name() == "headless":
		return false
	return (
		DisplayServer.window_get_mode()
		in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	)


func fullscreen_label() -> String:
	if OS.has_feature("web"):
		return str(
			JavaScriptBridge.eval(
				"window.initialsjFullscreenLabel ? window.initialsjFullscreenLabel() : 'ENTER FULLSCREEN'"
			)
		)
	return "EXIT FULLSCREEN" if is_fullscreen() else "ENTER FULLSCREEN"


func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.initialsjToggleFullscreen && window.initialsjToggleFullscreen()")
	elif DisplayServer.get_name() != "headless":
		if is_fullscreen():
			DisplayServer.window_set_mode(return_mode)
		else:
			return_mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# 브라우저는 사용자 동작으로만 전체화면을 허용하므로 설정 화면의 버튼 위에 DOM 버튼을 겹친다.
func hide_control() -> void:
	if not control_visible:
		return
	control_visible = false
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").initialsjFullscreenControl(false, 0, 0, 0, 0)


func sync_control(design_rect: Rect2) -> void:
	if not OS.has_feature("web"):
		return
	if race.state != RaceState.SETTINGS or busy():
		hide_control()
		return
	var viewport_size := race.get_viewport().get_visible_rect().size
	var rect := Rect2(
		(design_rect.position * race.hud.ui_scale() + race.hud.ui_offset()) / viewport_size,
		design_rect.size * race.hud.ui_scale() / viewport_size
	)
	if control_visible and control_rect.is_equal_approx(rect):
		return
	control_visible = true
	control_rect = rect
	JavaScriptBridge.get_interface("window").initialsjFullscreenControl(
		true, rect.position.x, rect.position.y, rect.size.x, rect.size.y
	)


func busy() -> bool:
	return race.screen_transition != null and race.screen_transition.busy


# 홈 화면에서만 브라우저의 뒤로 가기가 페이지를 떠나게 둔다.
func sync_back() -> void:
	if back_callback != null:
		JavaScriptBridge.get_interface("window").initialsjSetBackEnabled(
			race.state != RaceState.MENU or race.passport_open or busy()
		)


func hold_back() -> void:
	if back_callback != null:
		JavaScriptBridge.get_interface("window").initialsjSetBackEnabled(true)


func on_back(_args: Array) -> void:
	race.navigate_back()


func on_orientation(args: Array) -> void:
	portrait = bool(args[0])
	if portrait:
		race.hud.fingers.clear()
		race.pause_tour()
