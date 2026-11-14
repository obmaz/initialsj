extends Control
const SettingsAudio = preload("res://scripts/ui/settings_audio.gd")
const HudLayout = preload("res://scripts/ui/race_hud_layout.gd")
const MenuLayout = preload("res://scripts/ui/menu_layout.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const WorldCar = preload("res://scripts/physics/world_car.gd")
const RaceState = preload("res://scripts/race/race_state.gd")

# 메뉴 조립기도 hud.AppVersion으로 버전을 표시한다.
const AppVersion = preload("res://scripts/platform/app_version.gd")
const DESIGN := Vector2(1280, 720)
const INK := Color("2b506bdc")
const CYAN := Color("a7cce0")
const WHITE := Color("f6f7fa")
const GOLD := Color("dfbd69")
const FONT = preload("res://assets/ui/rev3/fonts/interface_font.tres")
const CAPTION_FONT = preload("res://assets/fonts/LiberationSans-BoldItalic.ttf")
const NUMBER_FONT = preload("res://assets/fonts/Roboto-BlackItalic.ttf")
const Library = preload("res://scripts/track/route_library.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var ROUTE_LEFT: Rect2:
	get:
		return rev3.rect("route_left", "tour_hud")
var ROUTE_RIGHT: Rect2:
	get:
		return rev3.rect("route_right", "tour_hud")
var PAUSE_BUTTON: Rect2:
	get:
		return top_hud_rects().pause
var HOME_TOUR: Rect2:
	get:
		return rev3.rect("tour", "start")
var HOME_TRACK: Rect2:
	get:
		return rev3.rect("track", "start")
var HOME_PASSPORT: Rect2:
	get:
		return rev3.home_passport_rect()
var PASSPORT_CLOSE: Rect2:
	get:
		return rev3.rect("back", "tour_passport")
var GARAGE_TUNING: Rect2:
	get:
		return rev3.rect("tuning", "car_select")
var HOME_SETTINGS: Rect2:
	get:
		return rev3.rect("settings", "start")
var COURSE_WEATHER: Rect2:
	get:
		return rev3.rect("weather", "track_select")
var COURSE_PERIOD: Rect2:
	get:
		return rev3.rect("time", "track_select")
var COURSE_FUJI: Rect2:
	get:
		rev3.sync()
		return rev3.course_rect(0)
var COURSE_SPEEDWAY: Rect2:
	get:
		rev3.sync()
		return rev3.course_rect(1)
var COURSE_NIGHT: Rect2:
	get:
		rev3.sync()
		return rev3.course_rect(2)
var COURSE_RIVIERA: Rect2:
	get:
		rev3.sync()
		return rev3.course_rect(3)
var COURSE_GORGE: Rect2:
	get:
		rev3.sync()
		return rev3.course_rect(4)
var menu_feedback := preload("res://scripts/ui/menu_feedback.gd").new()
var menu_text := preload("res://scripts/ui/menu_text.gd").new(self)
var menus := preload("res://scripts/ui/hud_menus.gd").new(self)
var rev3 := preload("res://scripts/ui/rev3_interface.gd").new(self)
var GARAGE_BACK: Rect2:
	get:
		return rev3.rect("back", "car_select")
var GARAGE_PREVIOUS: Rect2:
	get:
		return rev3.rect("previous_vehicle", "car_select")
var GARAGE_NEXT: Rect2:
	get:
		return rev3.rect("next_vehicle", "car_select")
var SETTINGS_PANEL: Rect2:
	get:
		return top_hud_bounds()
var SETTINGS_SOUND: Rect2:
	get:
		return rev3.rect("sound_panel", "settings")
var SETTINGS_MUSIC: Rect2:
	get:
		return rev3.rect("music_panel", "settings")
var SETTINGS_MOTION: Rect2:
	get:
		return rev3.rect("motion", "settings")
var SETTINGS_GRAPHICS: Rect2:
	get:
		return rev3.rect("graphics_panel", "settings")
var SETTINGS_FPS: Rect2:
	get:
		return rev3.rect("fps", "settings")
var SETTINGS_AUTO: Rect2:
	get:
		return rev3.rect("auto_acceleration", "settings")
var SETTINGS_FULLSCREEN: Rect2:
	get:
		return rev3.web_rect(0)
var SETTINGS_INSTALL: Rect2:
	get:
		return rev3.web_rect(1)
var SETTINGS_CLOSE: Rect2:
	get:
		return rev3.rect("done", "settings")
const RECOVERY_BUTTON := Rect2(500, 176, 280, 64)
var GARAGE_START: Rect2:
	get:
		return rev3.rect("start_race", "car_select")
var MAIN_MENU_BUTTON: Rect2:
	get:
		return rev3.rect("home", "pause")
var START_BUTTON: Rect2:
	get:
		return rev3.rect("resume", "pause")
var race: Node3D
var hud_card_style := StyleBoxFlat.new()
var controls_open := false
var audio_drags: Dictionary = {}
var modal_motion := preload("res://scripts/ui/modal_motion.gd").new()
var fingers: Dictionary = {}
var joystick := preload("res://scripts/input/floating_joystick.gd").new()
var recovery_touches: Dictionary = {}
var install_note := ""
var garage_notice := ""
var garage_notice_left := 0.0
var previous_vehicle := 0
var selection_blend := 1.0
var shown_abilities := PackedFloat32Array()
var drift_combo := 0.0
var drift_fade := 0.0
var last_score := 0.0
var was_drifting := false
var buttons: Dictionary = preload("res://scripts/input/touch_layout.gd").BASE.duplicate()


func _ready() -> void:
	hud_card_style.bg_color = Color("102b3d99")
	hud_card_style.border_color = Color("82a4b56e")
	hud_card_style.set_border_width_all(1)
	hud_card_style.set_corner_radius_all(10)
	menu_text.prepare()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func vehicle_changed(old_index: int) -> void:
	previous_vehicle = old_index
	selection_blend = 0.0 if not race.motion_reduced else 1.0
	if race.screen_transition != null and race.sound_enabled:
		race.screen_transition.transition_sound.play()


func ui_scale() -> float:
	return MenuLayout.scale_for(MenuLayout.safe_rect(get_viewport_rect().size))


func ui_offset() -> Vector2:
	return MenuLayout.origin_for(MenuLayout.safe_rect(get_viewport_rect().size))


func to_design(pos: Vector2) -> Vector2:
	return (pos - ui_offset()) / ui_scale()


func modal_key() -> String:
	if race.state in [RaceState.FINISHED, RaceState.FAILED] and race.result_age < 1.2:
		return ""
	if race.state == RaceState.SETTINGS and controls_open:
		return "controls"
	return (
		race.state if race.state in [RaceState.SETTINGS, RaceState.PAUSED, RaceState.FINISHED, RaceState.FAILED] else ""
	)


func modal_pose() -> Transform2D:
	# 조립된 원화의 안전 영역은 고정한다. 닫기 콜백의 단일 실행은 ModalMotion이 담당한다.
	return Transform2D.IDENTITY


func modal_begin() -> void:
	modal_motion.advance(modal_key(), 0, race.motion_reduced)
	var base := Transform2D(0, Vector2.ONE * ui_scale(), 0, ui_offset())
	draw_set_transform_matrix(base * modal_pose())
	menu_text.content_transform = modal_pose()


func modal_end() -> void:
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	menu_text.content_transform = Transform2D.IDENTITY


func animate_modal_close(action: Callable) -> bool:
	if DisplayServer.get_name() == "headless" or race.motion_reduced or modal_key() == "":
		return false
	if race.screen_transition != null and race.screen_transition.busy:
		return false
	modal_motion.close(modal_key(), action)
	clear_driving_input()
	race.shell.hide_control()
	return true


func top_hud_bounds() -> Rect2:
	var safe := MenuLayout.safe_rect(get_viewport_rect().size)
	var scale_factor := MenuLayout.scale_for(safe)
	return Rect2((safe.position - MenuLayout.origin_for(safe)) / scale_factor, safe.size / scale_factor)


func top_hud_rects() -> Dictionary:
	return HudLayout.top_rects(top_hud_bounds())


func pause_touch_rect() -> Rect2:
	return top_hud_rects().pause.grow(18).intersection(top_hud_bounds())


func configure_pedals() -> void:
	buttons = race.touch_layout.rectangles(race.auto_accelerate).duplicate()
	buttons.pause = top_hud_rects().pause
	var bounds := top_hud_bounds()
	for action in buttons:
		if action == "pause":
			continue
		var bounds_button: Rect2 = buttons[action]
		bounds_button.position += Vector2(
			bounds.position.x if bounds_button.get_center().x < 640 else bounds.end.x - 1280, bounds.end.y - 720
		)
		buttons[action] = bounds_button


func hit_button(action: String, pos: Vector2) -> bool:
	if not buttons.has(action):
		return false
	if action == "pause":
		return pause_touch_rect().has_point(pos)
	var padding := 1.18 if OS.has_feature("web") or OS.has_feature("mobile") else 1.0
	return button_at(pos, padding) == action


# 여유 영역이 겹쳐도 한 포인터는 가장 가까운 활성 버튼 하나만 누른다.
func button_at(pos: Vector2, padding: float = 1.18) -> String:
	configure_pedals()
	var nearest := INF
	var selected := ""
	for action in buttons:
		if action == "pause" or (action == "gas" and race.auto_accelerate):
			continue
		if action == "cell" and race.vehicle.mode != "hybrid":
			continue
		var rect: Rect2 = buttons[action]
		var radius: float = rect.size.x * 0.5 * padding
		var distance_squared := pos.distance_squared_to(rect.get_center())
		if distance_squared <= radius * radius and distance_squared < nearest:
			nearest = distance_squared
			selected = action
	return selected


func handle_pointer(event: InputEvent) -> void:
	if is_instance_valid(race.tuning_shop):
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = event.index if event is InputEventScreenTouch else -1
	if not event.pressed:
		joystick.release(index)
		if audio_drags.has(index):
			audio_drags.erase(index)
			race.save_preferences()
		fingers.erase(index)
		recovery_touches.erase(index)
		return
	if modal_motion.closing:
		return
	if recovery_touches.has(index):
		return
	var p := to_design(event.position)
	register_menu_press(p)
	if rev3.press(p, index):
		return
	if recovery_visible() and recovery_touch_rect().has_point(p):
		recovery_touches[index] = true
		fingers.erase(index)
		race.recover_car()
		return
	if race.route_choices_visible():
		if route_touch_rect(0).has_point(p):
			race.select_route(0)
			return
		if route_touch_rect(1).has_point(p):
			race.select_route(1)
			return
	if hit_button("pause", p) and race.state in RaceState.DRIVING:
		race.pause_tour()
	elif steering_zone().has_point(p):
		joystick.begin(index, p, HudLayout.STICK_TRAVEL * race.touch_layout.SIZES[race.touch_layout.size_index])
	else:
		move_pointer(index, event.position)


func install_game() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.initialsjInstallGame()")
	else:
		install_note = "OPEN THE WEB VERSION TO INSTALL"


func pad_on() -> bool:
	return race != null and race.gamepad_active


func badge_width(text: String) -> float:
	return maxf(34.0, FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20.0)


# The pad button that does an action, drawn as a small badge centred on `at`.
func pad_badge(at: Vector2, action: String) -> void:
	if not pad_on():
		return
	var text: String = race.pad.label(action)
	if text.is_empty():
		return
	var rect := Rect2(at - Vector2(badge_width(text) / 2, 14), Vector2(badge_width(text), 28))
	draw_rect(rect, Color("08141ff2"))
	draw_rect(rect, GOLD, false, 2.0)
	centered(at + Vector2(0, 7), text, 18, GOLD)


# A centred row of "badge + word" prompts under the current screen.
func pad_hints(items: Array, y: float, center_x: float = 640.0) -> void:
	var total := -30.0
	for item in items:
		total += (
			badge_width(race.pad.label(item[0]))
			+ 8
			+ FONT.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			+ 30
		)
	var x := center_x - total / 2
	for item in items:
		var badge: String = race.pad.label(item[0])
		var width := badge_width(badge)
		var rect := Rect2(x, y - 14, width, 28)
		var bright: bool = race.state in [RaceState.PAUSED, RaceState.FINISHED, RaceState.FAILED]
		draw_rect(rect, MenuTheme.SOFT if bright else Color("08141ff2"))
		draw_rect(rect, MenuTheme.TEAL if bright else GOLD, false, 2.0)
		centered(Vector2(x + width / 2, y + 7), badge, 18, GOLD)
		text_at(Vector2(x + width + 8, y + 7), item[1], 20, WHITE)
		x += width + 8 + FONT.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 30


# The gold frame shows which card the pad will open.
func draw_pad_focus() -> void:
	var rects := []
	if race.state == RaceState.MENU:
		rects = [HOME_TOUR, HOME_TRACK, HOME_SETTINGS]
	elif race.state == RaceState.COURSES:
		rects = [
			COURSE_FUJI,
			COURSE_SPEEDWAY,
			COURSE_NIGHT,
			COURSE_RIVIERA,
			COURSE_GORGE,
			GARAGE_BACK,
			COURSE_WEATHER,
			COURSE_PERIOD
		]
	if rects.is_empty():
		return
	var rect: Rect2 = rects[clampi(race.menu_focus, 0, rects.size() - 1)]
	draw_rect(rect.grow(5), MenuTheme.TEAL, false, 3.0)


func draw_pad_hints() -> void:
	if not pad_on():
		return
	draw_pad_focus()
	if race.state in RaceState.MENUS or race.state == RaceState.READY:
		return
	match race.state:
		RaceState.PAUSED:
			pad_hints([["confirm", "RESUME"], ["alt", "MAIN MENU"], ["alt2", "RESTART"]], 704)
		RaceState.FINISHED, RaceState.FAILED:
			pad_hints([["confirm", race.result_button_label()], ["back", "BACK"], ["alt", "RETRY"]], 704)


func draw_pad_badges() -> void:
	if not pad_on() or race.state not in [RaceState.RACING, RaceState.COUNTDOWN, RaceState.PAUSED]:
		return
	for action in ["gas", "brake", "drift", "nitro"]:
		if action == "gas" and race.auto_accelerate:
			continue
		var rect: Rect2 = buttons[action]
		pad_badge(rect.get_center() + Vector2(-1, -1) * rect.size.x * 0.36, action)
	if race.vehicle.mode == "hybrid":
		var cell: Rect2 = buttons.cell
		pad_badge(cell.get_center() + Vector2(-1, -1) * cell.size.x * 0.36, "cell")
	pad_badge(Vector2(147, 690), "steer")
	pad_badge(top_hud_rects().pause.get_center() + Vector2(0, 48), "pause")


func move_pointer(index: int, pos: Vector2) -> void:
	if joystick.active() and joystick.pointer == index:
		joystick.move(index, to_design(pos))
		return
	if audio_drags.has(index):
		if race.state == RaceState.SETTINGS and not controls_open and not modal_motion.closing:
			SettingsAudio.slide(self, audio_drags[index], to_design(pos))
		return
	if recovery_touches.has(index) or race.state not in RaceState.DRIVING:
		return
	fingers[index] = to_design(pos)


func held(action: String) -> bool:
	for pos in fingers.values():
		if hit_button(action, pos):
			return true
	return false


func clear_driving_input() -> void:
	fingers.clear()
	joystick.reset()


func steering_zone() -> Rect2:
	var bounds := HudLayout.steering_zone(race.touch_layout.mirrored)
	var safe := top_hud_bounds()
	bounds.position += Vector2(safe.end.x - 1280 if race.touch_layout.mirrored else safe.position.x, safe.end.y - 720)
	return bounds


func steering_rest() -> Vector2:
	var safe := top_hud_bounds()
	return (
		HudLayout.steering_rest(race.touch_layout.mirrored)
		+ Vector2(safe.end.x - 1280 if race.touch_layout.mirrored else safe.position.x, safe.end.y - 720)
	)


func touch_axis() -> float:
	return joystick.axis()


func show_garage_notice(value: String) -> void:
	garage_notice = value
	garage_notice_left = 4
	queue_redraw()


func _process(delta: float) -> void:
	if race == null:
		return
	MenuLayout.expand_menu(
		get_window(), race.state in [RaceState.MENU, RaceState.COURSES, RaceState.READY, RaceState.SETTINGS]
	)
	modal_motion.advance(
		modal_key(), delta, race.motion_reduced, race.screen_transition != null and race.screen_transition.busy
	)
	garage_notice_left = maxf(0, garage_notice_left - delta) if race.state == RaceState.READY else 0
	rev3.sync()
	if race.state not in RaceState.DRIVING:
		joystick.reset()
	if (race.state != RaceState.SETTINGS or controls_open or modal_motion.closing) and not audio_drags.is_empty():
		audio_drags.clear()
		race.save_preferences()
	if race.state != RaceState.RACING:
		recovery_touches.clear()
	menu_feedback.advance(delta, menu_press_context())
	selection_blend = minf(1, selection_blend + delta * 5)
	var target: Dictionary = Catalog.abilities(race.selected_vehicle)
	if shown_abilities.size() != 4:
		for key in Catalog.ABILITY_KEYS:
			shown_abilities.append(target[key])
	for i in range(4):
		shown_abilities[i] = lerpf(
			shown_abilities[i], target[Catalog.ABILITY_KEYS[i]], 1.0 if race.motion_reduced else 1 - exp(-delta * 12)
		)
	if race.state in [RaceState.READY, RaceState.COUNTDOWN] or race.score < last_score:
		drift_combo = 0
		drift_fade = 0
		was_drifting = false
	if race.state == RaceState.RACING:
		if race.drifting:
			if not was_drifting:
				drift_combo = 0
			drift_combo += maxf(0, race.score - last_score)
			drift_fade = 1.5
		else:
			drift_fade = maxf(0, drift_fade - delta)
		was_drifting = race.drifting
	last_score = race.score
	queue_redraw()


func text_at(
	pos: Vector2, value: String, size_px: int, color: Color = WHITE, shadow: bool = true, face: Font = FONT
) -> void:
	value = tr(value)
	if race != null and (race.passport_open or race.state in RaceState.MENUS or race.state == RaceState.READY):
		shadow = false
		if color == WHITE:
			color = MenuTheme.INK
		elif color == CYAN:
			color = MenuTheme.TEAL
		elif color == GOLD:
			color = MenuTheme.TEAL
	if shadow:
		draw_string_outline(
			face,
			pos + Vector2(0.5, 1.5),
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			size_px,
			3,
			Color(0.02, 0.02, 0.04, color.a * 0.62)
		)
	draw_string(face, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func centered(pos: Vector2, value: String, size_px: int, color: Color = WHITE, face: Font = FONT) -> void:
	text_at(
		pos - Vector2(face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2, 0),
		value,
		size_px,
		color,
		true,
		face
	)


func slant(rect: Rect2, color: Color = INK, cut: float = 16, fade: bool = false) -> PackedVector2Array:
	var p := PackedVector2Array(
		[
			rect.position + Vector2(cut, 0),
			rect.position + Vector2(rect.size.x, 0),
			rect.end - Vector2(cut, 0),
			rect.position + Vector2(0, rect.size.y)
		]
	)
	if fade:
		# Hold the dark/blue colour under the lettering, then feather the trailing edge.
		var top := p[0].lerp(p[1], 0.52)
		var bottom := p[3].lerp(p[2], 0.52)
		draw_colored_polygon(PackedVector2Array([p[0], top, bottom, p[3]]), color)
		draw_polygon(
			PackedVector2Array([top, p[1], p[2], bottom]),
			PackedColorArray([color, Color(color, 0), Color(color, 0), color])
		)
	else:
		draw_colored_polygon(p, color)
	return p


func rounded_rect(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5, 0.0],
		[rect.end - Vector2(r, r), 0.0, PI * 0.5],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5, PI],
		[rect.position + Vector2(r, r), PI, PI * 1.5],
	]
	for c in corners:
		var center: Vector2 = c[0]
		var a1: float = c[1]
		var a2: float = c[2]
		for step in range(5):
			var a := lerpf(a1, a2, step / 4.0)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func glass_box(
	rect: Rect2,
	radius: float = 12.0,
	fill: Color = Color("0b1526cc"),
	border: Color = Color("19dcff44"),
	border_width: float = 1.5
) -> void:
	var pts := rounded_rect(rect, radius)
	var colors := PackedColorArray()
	for point in pts:
		var color := fill.lightened(.045).lerp(fill.darkened(.12), (point.y - rect.position.y) / maxf(rect.size.y, 1))
		color.a = fill.a
		colors.append(color)
	draw_polygon(pts, colors)
	pts.append(pts[0])
	draw_polyline(pts, Color(border, border.a * .16), border_width + 5, true)
	draw_polyline(pts, border, border_width, true)
	draw_line(
		rect.position + Vector2(radius + 3, 2),
		Vector2(rect.end.x - radius - 3, rect.position.y + 2),
		Color(border, border.a * .45),
		1,
		true
	)


func glow_line(points: PackedVector2Array, color: Color = CYAN, width: float = 2) -> void:
	# Two soft halos (not antialiased: they are blurry anyway, and an antialiased wide polyline is
	# costly to build every frame) and the sharp core line.
	for layer in [Vector2(14, 0.04), Vector2(5, 0.12)]:
		draw_polyline(points, Color(color, color.a * layer.y), width + layer.x, false)
	draw_polyline(points, color, width, true)


func rounded_polygon(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size()):
		var corner := points[i]
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		var enter := corner + (previous - corner).normalized() * radius
		var leave := corner + (next - corner).normalized() * radius
		for j in range(5):
			var t := j / 4.0
			result.append(enter.lerp(corner, t).lerp(corner.lerp(leave, t), t))
	return result


var circle_cache := {}


func arc_points(center: Vector2, radius: float, start: float, end: float, steps: int = 80) -> PackedVector2Array:
	# Full circles (button rings) never change, so they are built once.
	var full := is_equal_approx(end - start, TAU) and start == 0.0
	var key := Vector3(center.x, center.y, radius)
	if full and steps == 80 and circle_cache.has(key):
		return circle_cache[key]
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / steps)) * radius)
	if full and steps == 80:
		if circle_cache.size() > 32:
			circle_cache.clear()
		circle_cache[key] = points
	return points


func time_label(seconds: float) -> String:
	var ticks := roundi(maxf(0, seconds) * 1000)
	return "%02d:%02d.%03d" % [ticks / 60000, (ticks / 1000) % 60, ticks % 1000]


func _draw() -> void:
	menu_text.begin()
	draw_content()
	draw_menu_press()
	menu_text.finish()


func draw_content() -> void:
	if race == null:
		return
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	rev3.draw()


func comma_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result


func route_map_point(row: int, node: int, rect: Rect2 = Rect2()) -> Vector2:
	return HudLayout.route_point(row, node, rect if rect.has_area() else top_hud_rects().minimap)


func draw_minimap() -> void:
	if race.mode == "track":
		draw_circuit_map()
		return
	var selected := 0
	var rect: Rect2 = top_hud_rects().minimap
	for row in range(5):
		if row > 0 and row - 1 < race.track.history.size():
			selected += race.track.history[row - 1]
		for node in range(row + 1):
			var p := route_map_point(row, node, rect)
			if row < 4:
				for side in [0, 1]:
					draw_line(p, route_map_point(row + 1, node + side, rect), Color("071323d9"), 5, true)
					draw_line(p, route_map_point(row + 1, node + side, rect), Color("d0e4ed"), 2, true)
			var visited: bool = row <= race.stage_index and node == selected
			draw_circle(p, 7 if visited else 6, Color("071323"))
			draw_circle(p, 4.5 if visited else 3.5, CYAN if visited else Color("91adbd"))
			if visited and row > 0:
				var previous: int = selected - race.track.history[row - 1]
				draw_line(route_map_point(row - 1, previous, rect), p, CYAN, 2, true)
	var current := route_map_point(race.stage_index, race.route_node, rect)
	draw_arc(current, 7, 0, TAU, 24, Color("071323"), 5, true)
	draw_arc(current, 7, 0, TAU, 24, GOLD, 2, true)


var map_outline := PackedVector2Array()
var map_outline_key := ""


func circuit_map_point(d: float, rect: Rect2) -> Vector2:
	var p: Vector3 = race.track.point(d)
	return HudLayout.project_map(Vector2(p.x, p.z), race.track.map_bounds, rect)


func draw_circuit_map() -> void:
	var rect: Rect2 = top_hud_rects().minimap
	# 화면·안전 영역 변경 시에도 지도 선을 새 기준점에 다시 맞춘다.
	var key := "%s:%s:%s:%s" % [race.track.active.get_instance_id(), race.track.length, race.track.map_bounds, rect]
	if map_outline_key != key:
		map_outline_key = key
		map_outline = PackedVector2Array()
		for i in range(101):
			map_outline.append(circuit_map_point(race.track.length * i / 100.0, rect))
	draw_polyline(map_outline, Color("071323e6"), 6, true)
	draw_polyline(map_outline, Color("f3fbff"), 2.5, true)
	for r in race.rivals:
		if r.active:
			draw_circle(circuit_map_point(r.distance, rect), 5, Color("071323"))
			draw_circle(circuit_map_point(r.distance, rect), 3, Color("f38e7c"))
	if race.world_race != null:
		var body: CharacterBody3D = race.world_race.player_body
		var p := HudLayout.project_map(Vector2(body.position.x, body.position.z), race.track.map_bounds, rect)
		var forward: Vector3 = body.forward_direction()
		var direction := Vector2(forward.x, forward.z).normalized()
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(
			PackedVector2Array([p + direction * 10, p - direction * 6 + side * 7, p - direction * 6 - side * 7]),
			Color("071323")
		)
		draw_colored_polygon(
			PackedVector2Array([p + direction * 7, p - direction * 4 + side * 4, p - direction * 4 - side * 4]), GOLD
		)
	else:
		draw_circle(circuit_map_point(race.distance, rect), 5, CYAN)
	draw_rect(Rect2(circuit_map_point(80, rect) - Vector2(3, 3), Vector2(6, 6)), GOLD)


func draw_drift_score() -> void:
	if race.coast_handling:
		draw_coast_drift()
		return
	if drift_fade <= 0:
		return
	var alpha := minf(1, drift_fade * 2)
	slant(Rect2(1124, 263, 170, 70), Color(0.07, 0.07, 0.12, alpha * 0.14), 13, true)
	text_at(Vector2(1165, 289), "DRIFT", 27, Color(WHITE, alpha), true, CAPTION_FONT)
	text_at(Vector2(1143, 319), "+%d pts" % int(drift_combo), 30, Color(GOLD, alpha), true, NUMBER_FONT)
	glow_line(PackedVector2Array([Vector2(1138, 333), Vector2(1279, 323)]), Color(CYAN, alpha), 2)


func nitro_ready() -> bool:
	return race.nitro_ratio() >= .999 and not race.nitro_active and race.nitro_burst_left <= 0


func draw_nitro_ready(rect: Rect2) -> void:
	var centre := rect.get_center()
	var radius := rect.size.x * .5 + 3
	var animate: bool = not race.motion_reduced and race.state == RaceState.RACING
	var time := Time.get_ticks_msec() * .001 if animate else 0.0
	draw_arc(centre, radius, 0, TAU, 64, Color("ffca67b0"), 2, true)
	if not animate:
		return
	var count := 8 if race.lite_graphics else 12
	for i in range(count):
		var angle := TAU * i / count + time * .22
		var height := 5 + (sin(time * 4 + i * 2.3) + 1) * 5
		var edge := minf(minf(centre.x, HudLayout.DESIGN.x - centre.x), minf(centre.y, HudLayout.DESIGN.y - centre.y))
		height = minf(height, maxf(0, edge - radius - 2))
		var base := centre + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI * .5) * 4
		draw_colored_polygon(
			PackedVector2Array(
				[base - tangent, centre + Vector2.from_angle(angle + .035) * (radius + height), base + tangent]
			),
			Color("ffb14bc0") if i % 2 == 0 else Color("ff79468c")
		)


func garage_card(index: int) -> Rect2:
	return rev3.garage_card(index)


var fps_text := ""
var fps_value := 0.0
var fps_updated := 0


func draw_fps() -> void:
	if not race.show_fps:
		return
	var now := Time.get_ticks_msec()
	if now - fps_updated > 500 or fps_text == "":
		fps_updated = now
		fps_value = Engine.get_frames_per_second()
		fps_text = "%d FPS" % roundi(fps_value)
	var color := Color("7dffb0") if fps_value >= 55 else (Color("ffd166") if fps_value >= 40 else Color("ff6b5a"))
	text_at(Vector2(24, 204), fps_text, 18, color)


func draw_slipstream_target() -> void:
	if race.state != RaceState.RACING or race.slipstream.charge < .1 or race.slipstream.target_id == 0:
		return
	var target: WorldCar = instance_from_id(race.slipstream.target_id) as WorldCar
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var world: Vector3 = target.global_position + Vector3.UP * 3.8
	if race.camera.is_position_behind(world):
		return
	var point := to_design(race.camera.unproject_position(world))
	if not Rect2(275, 175, 745, 275).has_point(point):
		return
	var color: Color = GOLD if race.slipstream.ready else CYAN
	var chevron := PackedVector2Array([point + Vector2(-10, -7), point + Vector2(0, 1), point + Vector2(10, -7)])
	draw_polyline(chevron, INK, 7, true)
	draw_polyline(chevron, color, 3, true)


func draw_competitor_markers() -> void:
	if race.mode != "track" or race.state not in RaceState.DRIVING:
		return
	var nearby: Array[Dictionary] = []
	for rival in race.rivals:
		if not rival.active or not rival.car.visible:
			continue
		var gap: float = race.relative_gap(rival.distance, race.distance)
		if gap > 7 and gap < 100:
			nearby.append({"rival": rival, "gap": gap})
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.gap < b.gap)
	var occupied: Array[Rect2] = []
	for entry in nearby:
		var rival: RefCounted = entry.rival
		var world: Vector3 = rival.car.position + Vector3.UP * 2.2
		if race.camera.is_position_behind(world):
			continue
		var point := to_design(race.camera.unproject_position(world))
		if point.x < 275 or point.x > 1020 or point.y < 175 or point.y > 450:
			continue
		var rect := Rect2(point - Vector2(24, 25), Vector2(48, 25))
		var overlaps := false
		for previous in occupied:
			if rect.grow(5).intersects(previous):
				overlaps = true
		if overlaps:
			continue
		occupied.append(rect)
		var place: int = race.competitor_position(rival.id)
		var suffix := "st" if place == 1 else ("nd" if place == 2 else ("rd" if place == 3 else "th"))
		slant(rect, Color("111724d9"), 5)
		centered(Vector2(point.x, point.y - 6), str(place) + suffix, 18, GOLD if place == 1 else WHITE)
		if occupied.size() >= 3:
			break


# Game messages sit on a dark plate with a heavy outline and an accent underline, so they read
# over sky, asphalt and the car alike. A new message pops in (skipped with reduced motion).
# Big events stack from the top banner lane; status messages sit under the horizon.
const BANNER_Y := 158.0
const BANNER_STEP := 42.0
const STATUS_Y := 236.0
const STATUS_STEP := 36.0
const TOAST_SCALE := 0.72
const WARNING := Color("ff6b5a")


func toast(center: Vector2, value: String, size_px: int, accent: Color, alpha: float = 1.0, pop: float = 0.0) -> void:
	alpha = clampf(alpha, 0, 1)
	if alpha <= 0:
		return
	# Messages are kept compact so they never cover the road ahead.
	size_px = maxi(14, roundi(size_px * TOAST_SCALE))
	var scale := 1.0 + (0.0 if race.motion_reduced else 0.16 * pop)
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var ui := Transform2D(Vector2(ui_scale(), 0), Vector2(0, ui_scale()), ui_offset())
	draw_set_transform_matrix(ui * Transform2D(Vector2(scale, 0), Vector2(0, scale), center * (1.0 - scale)))
	var pad := size_px * 0.6
	var plate := Rect2(center.x - width / 2 - pad, center.y - size_px * 0.62, width + pad * 2, size_px * 1.4)
	slant(plate, Color(0.03, 0.06, 0.10, 0.72 * alpha), size_px * 0.28)
	draw_rect(
		Rect2(plate.position.x + size_px * 0.28, plate.end.y - 3, plate.size.x - size_px * 0.56, 3),
		Color(accent, alpha)
	)
	var origin := Vector2(center.x - width / 2, center.y + size_px * 0.36)
	draw_string_outline(
		FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0.01, 0.02, 0.04, 0.95 * alpha)
	)
	draw_string(FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(accent.lightened(0.25), alpha))
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())


# Minor, informational messages (slipstream, nitro, pass, air time, wet road...) stay small,
# faint and high on the screen over the horizon, so they never sit on the road ahead.
const HINT_Y := 108.0


func hint(value: String, accent: Color, alpha: float = 1.0) -> void:
	alpha = clampf(alpha, 0, 1) * 0.62
	if alpha <= 0.02:
		return
	var size_px := 19
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var plate := Rect2(640 - width / 2 - 14, HINT_Y - size_px * 0.9, width + 28, size_px * 1.55)
	slant(plate, Color(0.03, 0.06, 0.10, 0.34 * alpha), 8)
	var origin := Vector2(640 - width / 2, HINT_Y + size_px * 0.3)
	draw_string_outline(
		FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 3, Color(0.01, 0.02, 0.04, 0.7 * alpha)
	)
	draw_string(FONT, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(accent.lightened(0.2), alpha))


# How far into its life a timed message is: 1 at the start, falling to 0 over `window`.
func fresh(remaining: float, duration: float, window: float = 0.18) -> float:
	return clampf((remaining - (duration - window)) / window, 0, 1)


func draw_pace_feedback() -> void:
	if race.state != RaceState.RACING:
		return
	var banner := BANNER_Y
	if race.world_race != null and race.world_race.wrong_way_time > 0.65:
		toast(Vector2(640, banner), "WRONG WAY", 34, WARNING)
		banner += BANNER_STEP
	if race.return_flash > 0:
		toast(
			Vector2(640, banner),
			"BACK ON ROAD",
			38,
			GOLD,
			minf(1, race.return_flash * 2),
			fresh(race.return_flash, 1.6)
		)
		banner += BANNER_STEP
	if race.checkpoint_flash > 0 and not race.route_choices_visible():
		toast(
			Vector2(640, banner),
			tr("CHECKPOINT +%ds") % int(race.checkpoint_award),
			40,
			GOLD,
			minf(1, race.checkpoint_flash * 3),
			fresh(race.checkpoint_flash, 2.0)
		)
		banner += BANNER_STEP
	elif race.route_confirm_flash > 0:
		toast(
			Vector2(640, banner),
			race.route_confirm_title,
			36,
			CYAN,
			minf(1, race.route_confirm_flash * 3),
			fresh(race.route_confirm_flash, 1.4)
		)
	if race.launch_flash > 0:
		toast(Vector2(640, 350), "GO!", 78, GOLD, minf(1, race.launch_flash * 4), fresh(race.launch_flash, 0.7, 0.25))
	var intensity: float = clampf((race.speed - 38) / 50, 0, 1)
	if not race.motion_reduced:
		var origin := Vector2(640, 315)
		for i in range(34):
			var angle: float = TAU * fposmod(i * 0.61803398875, 1)
			var phase: float = fposmod(race.elapsed * (1.3 + intensity * 1.5) + i * 0.317, 1)
			var ray := Vector2.from_angle(angle) * Vector2(800, 500)
			var start := origin + ray * (0.70 + phase * 0.6)
			var end := start + ray.normalized() * (22 + phase * 80) * intensity
			draw_line(
				start,
				end,
				Color(0.65, 0.88, 1, intensity * (0.26 if race.boosting else 0.16) * sin(phase * PI)),
				1.2,
				true
			)
	if race.impact > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.35, 0.10, race.impact * 0.07))
	var status := STATUS_Y
	if race.air.active and race.air.trick:
		hint("AIR TIME", GOLD)
	elif race.air.landing_flash > 0.35 and race.air.trick:
		hint("LANDED +100", Color("b7e9ff"), minf(1, race.air.landing_flash * 2.5))
	elif race.pad_active:
		draw_boost_badge()
	elif race.surface.mud_flash > 0:
		hint("MUD", Color("d9b38a"), minf(1, race.surface.mud_flash * 2))
	elif race.surface.water_flash > 0:
		hint("WET ROAD", Color("a9dfff"), minf(1, race.surface.water_flash * 2))
	elif race.rewards.flash > 0:
		hint(race.rewards.message, GOLD, minf(1, race.rewards.flash * 3))
	elif race.near_miss_flash > 0:
		hint("CLOSE PASS +150", GOLD, minf(1, race.near_miss_flash * 2.5))
	elif race.overtake_flash > 0:
		hint("PASS", CYAN, minf(1, race.overtake_flash * 2.5))
	elif race.boosting and not race.nitro_active:
		hint("SKILL BOOST" if race.reward_boost_active() else "SLIPSTREAM", CYAN)
	if race.corner_warning > 0.15:
		toast(
			Vector2(640, status),
			"BRAKE / CORNER %d km/h" % int(race.recommended_speed * 3.6),
			26,
			WARNING,
			race.corner_warning
		)
	if race.hazard_text != "":
		toast(
			Vector2(640, status + (STATUS_STEP if race.corner_warning > 0.15 else 0)),
			"! " + race.hazard_text,
			26,
			WARNING
		)


# Road boosts get one short activation pulse, separate from nitro fuel and
# ordinary speed lines. Motion reduction keeps only the informative badge.
func boost_feedback_strength() -> float:
	if race == null or race.state != RaceState.RACING or not race.pad_active or race.motion_reduced:
		return 0
	var lane_active: bool = race.surface.lane_active
	var duration := 0.65 if lane_active else 1.1
	var pulse: float = pow(clampf(race.surface.pad_flash / duration, 0, 1), 2)
	return pulse if lane_active else pulse * smoothstep(0, 0.25, race.surface.pad_time)


func boost_feedback_label() -> String:
	if race == null or race.state != RaceState.RACING or not race.pad_active:
		return ""
	return "BOOST LANE" if race.surface.lane_active else "BOOST PAD"


func draw_boost_feedback() -> void:
	var pulse := boost_feedback_strength()
	if pulse <= 0:
		return
	# Keep the centre of the road and touch controls clear; no full-screen flash.
	for side in [-1.0, 1.0]:
		var edge := 0.0 if side < 0 else 1280.0
		var inner: float = edge - side * 78
		var points := PackedVector2Array(
			[Vector2(edge, 170), Vector2(inner, 320), Vector2(inner, 430), Vector2(edge, 570)]
		)
		draw_polygon(
			points,
			PackedColorArray([Color(CYAN, pulse * 0.16), Color(CYAN, 0), Color(CYAN, 0), Color(CYAN, pulse * 0.12)])
		)
		for i in range(4):
			var y := 212.0 + i * 76
			var direction := (Vector2(edge, y) - Vector2(640, 330)).normalized()
			var start := Vector2(inner, 330 + (y - 330) * 0.85) + direction * (1 - pulse) * 48
			var end := start + direction * (32 + pulse * 52)
			var across := Vector2(-direction.y, direction.x) * (1.6 + pulse * 0.8)
			var color := GOLD if i % 3 == 0 else CYAN
			draw_polygon(
				PackedVector2Array([start - across, start + across, end]),
				PackedColorArray([Color(color, pulse * 0.65), Color(color, pulse * 0.65), Color(color, 0)])
			)


func draw_boost_badge() -> void:
	var label := boost_feedback_label()
	if label.is_empty():
		return
	hint(label, GOLD, minf(1, race.surface.pad_flash * 2))


func recovery_visible() -> bool:
	return race != null and race.state == RaceState.RACING and race.get("recovery_available") == true


func recovery_touch_rect() -> Rect2:
	return RECOVERY_BUTTON.grow(6)


func draw_recovery() -> void:
	if not recovery_visible():
		return
	var outline := slant(RECOVERY_BUTTON, Color("192b37ed"), 10)
	draw_polyline(outline + PackedVector2Array([outline[0]]), Color(GOLD, 0.85), 2, true)
	var center := RECOVERY_BUTTON.position + Vector2(29, 32)
	draw_arc(center, 11, deg_to_rad(-35), deg_to_rad(260), 18, GOLD, 2, true)
	var tip := center + Vector2.from_angle(deg_to_rad(260)) * 11
	draw_colored_polygon(PackedVector2Array([tip + Vector2(5, -1), tip + Vector2(-3, -4), tip + Vector2(-2, 4)]), GOLD)
	centered(RECOVERY_BUTTON.position + Vector2(155, 42), "RESET CAR", 27, GOLD)
	pad_badge(RECOVERY_BUTTON.position + Vector2(-2, 2), "reset")


# Single-line route chips stay above the road view; their larger invisible
# touch areas are separate from the visuals so a phone remains easy to use.
func route_touch_rect(side: int) -> Rect2:
	return (ROUTE_LEFT if side == 0 else ROUTE_RIGHT).grow_individual(0, 5, 0, 5)


func route_title_size(title: String) -> int:
	for size_px in [26, 25, 24, 23, 22]:
		if FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= 224:
			return size_px
	return 22


func draw_route_choice() -> void:
	if not race.route_choices_visible():
		return
	var names := Library.next_titles(race.stage_index, race.route_node)
	var progress: float = clampf(
		(race.distance - race.track.active.checkpoint_distance()) / Library.CHECKPOINT_RUNUP, 0, 1
	)
	for side in range(2):
		var rect: Rect2 = ROUTE_LEFT if side == 0 else ROUTE_RIGHT
		var selected: bool = race.route_preference == side
		rev3.panel(rect, rev3.Art.BLUE, GOLD if selected else Color.TRANSPARENT)
		var center := rect.position + Vector2(28, rect.size.y * .5)
		var direction := -1 if side == 0 else 1
		draw_polyline(
			PackedVector2Array(
				[
					center + Vector2(-direction * 7, -12),
					center + Vector2(direction * 7, 0),
					center + Vector2(-direction * 7, 12)
				]
			),
			WHITE,
			4,
			true
		)
		rev3.label(Rect2(rect.position + Vector2(55, 2), Vector2(rect.size.x - 70, 36)), names[side], 24)
		var info: Dictionary = race.TourChallenge.choice(race, side)
		rev3.label(Rect2(rect.position + Vector2(55, 38), Vector2(rect.size.x - 70, 27)), info.hint, 17, GOLD)
		draw_rect(Rect2(rect.position + Vector2(8, rect.size.y - 3), Vector2((rect.size.x - 16) * progress, 3)), GOLD)
		pad_badge(rect.position + Vector2(8, -2), "route_left" if side == 0 else "route_right")


# 하트는 실제 미끄러짐으로 얻은 보상만 표시합니다. 슬롯은 일곱 개로 고정하여
# 긴 드리프트에도 이펙트 노드가 쌓이지 않으며 저감 모드에서는 흔들리지 않습니다.
func draw_coast_drift() -> void:
	var chain: RefCounted = race.coast_drift
	if chain.visible_time <= 0:
		return
	var alpha: float = minf(1, chain.visible_time * 2)
	var rose := Color("ff739e")
	rose.a = alpha
	slant(Rect2(895, 247, 362, 122), Color(0.025, 0.08, 0.14, alpha * 0.76), 14)
	text_at(
		Vector2(914, 276),
		(
			"CHAIN BROKEN"
			if chain.broken
			else (("GORGE DRIFT" if race.selected_course == 4 else "COAST DRIFT") if chain.active else "NICE SLIDE!")
		),
		22,
		rose
	)
	text_at(Vector2(1217, 275), "x%d" % chain.multiplier, 28, Color(GOLD, alpha), true, NUMBER_FONT)
	for i in range(7):
		var center := Vector2(928 + i * 38, 308)
		var scale := 0.68
		if i < chain.hearts and not race.motion_reduced:
			scale *= 1 + 0.09 * sin(race.elapsed * 6 - i * 0.8)
		draw_heart(center, scale, rose if i < chain.hearts else Color(0.7, 0.65, 0.72, alpha * 0.25))
	text_at(Vector2(914, 352), "+%s pts" % int(chain.points), 30, Color(WHITE, alpha), false, NUMBER_FONT)


func draw_heart(center: Vector2, size: float, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i in range(48):
		var t := TAU * i / 48
		polygon.append(
			center + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * size
		)
	draw_colored_polygon(polygon, color)


func settings_close_rect() -> Rect2:
	return rev3.rect("done", "settings")


func settings_controls_rect() -> Rect2:
	return rev3.rect("controls", "settings")


func open_controls() -> void:
	controls_open = true
	race.settings_focus = 0
	clear_driving_input()
	race.shell.hide_control()


func result_continue_rect() -> Rect2:
	rev3.sync()
	return rev3.rect("continue")


func menu_press_rects() -> Array[Rect2]:
	return [] if is_instance_valid(race.tuning_shop) else rev3.press_rects()


func menu_press_context() -> String:
	if race.passport_open:
		return race.state + ":passport"
	if controls_open:
		return race.state + ":controls"
	if is_instance_valid(race.tuning_shop):
		return race.state + ":tuning"
	return race.state


func register_menu_press(at: Vector2) -> void:
	if menu_feedback.press(at, menu_press_rects(), menu_press_context()):
		if race.sound_enabled and is_instance_valid(race.screen_transition):
			race.screen_transition.transition_sound.play()


func draw_menu_press() -> void:
	var amount := menu_feedback.amount()
	if amount <= 0 or menu_feedback.state != menu_press_context():
		return
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	var rect := menu_feedback.rect.grow(-8)
	if not race.motion_reduced:
		rect.position.y += 2 * amount
	draw_rect(rect, Color(.87, .74, .41, .12 * amount))
	draw_rect(rect, Color(.87, .74, .41, .75 * amount), false, 3, true)
	draw_line(
		rect.position + Vector2(14, 3),
		Vector2(rect.end.x - 14, rect.position.y + 3),
		Color(1, 1, 1, .8 * amount),
		2,
		true
	)
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
