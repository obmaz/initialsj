extends RefCounted
# 선택한 진단 URL에서만 실제 입력·주행 상태를 읽는다. 상태 변경 API는 제공하지 않는다.
var race: Node3D
var callback: JavaScriptObject


func _init(owner: Node3D) -> void:
	race = owner


func attach() -> void:
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('diagnostics') === '1'")):
		return
	callback = JavaScriptBridge.create_callback(reply)
	JavaScriptBridge.get_interface("window").initialsjReadDiagnostics = callback


func detach() -> void:
	if callback == null:
		return
	JavaScriptBridge.get_interface("window").initialsjReadDiagnostics = null
	callback = null


static func rectangle(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func snapshot() -> Dictionary:
	var hud: Control = race.hud
	hud.configure_pedals()
	var offset: Vector2 = hud.ui_offset()
	var size: Vector2 = hud.get_viewport_rect().size
	var screen: Transform2D = hud.get_viewport().get_final_transform() * hud.get_global_transform_with_canvas()
	var targets := {
		"home_tour": rectangle(hud.HOME_TOUR),
		"home_settings": rectangle(hud.HOME_SETTINGS),
		"settings_auto": rectangle(hud.SETTINGS_AUTO),
		"settings_close": rectangle(hud.settings_close_rect()),
		"garage_start": rectangle(hud.GARAGE_START),
		"garage_cards": [],
		"pause": rectangle(hud.pause_touch_rect()),
		"resume": rectangle(hud.START_BUTTON),
	}
	for i in range(race.Catalog.SPECS.size()):
		targets.garage_cards.append(rectangle(hud.garage_card(i)))
	for action in ["gas", "brake", "nitro"]:
		targets[action] = rectangle(hud.buttons[action])
	return {
		"schema": 1,
		"frame": Engine.get_process_frames(),
		"state": race.state,
		"selected_vehicle": race.selected_vehicle,
		"mode": race.mode,
		"speed_mps": race.speed,
		"auto_accelerate": race.auto_accelerate,
		"nitro_active": race.nitro_active,
		"nitro_charges": race.nitro_charges,
		"throttling": race.throttling,
		"braking": race.braking,
		"pedals": {"gas": hud.held("gas"), "brake": hud.held("brake"), "nitro": hud.held("nitro")},
		"viewport": {"width": size.x, "height": size.y},
		"screen_transform": [screen.x.x, screen.x.y, screen.y.x, screen.y.y, screen.origin.x, screen.origin.y],
		"ui_scale": hud.ui_scale(),
		"ui_offset": {"x": offset.x, "y": offset.y},
		"targets": targets,
	}


func reply(args: Array) -> void:
	if args.size() == 1 and args[0] != null:
		args[0].call("call", JSON.stringify(snapshot()))
