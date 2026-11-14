extends RefCounted
# 화면 그림과 입력은 같은 원화 좌표를 사용한다. 예제 차량·기록·경로는 실제 게임 자료로 바꾼다.
const Art = preload("res://scripts/ui/rev3_art.gd")
const State = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Library = preload("res://scripts/track/route_library.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const Audio = preload("res://scripts/ui/settings_audio.gd")
const Challenge = preload("res://scripts/race/tour_challenge.gd")
const TITLES := ["FUJI LAKESIDE", "SUNCOAST SPEEDWAY", "MIDNIGHT HARBOR", "AZURE RIVIERA", "SCARLET GORGE"]
const COURSE_PROFILES := [
	"res://models/world/track_0/profile.tres",
	"res://models/world/track_1/profile.tres",
	"res://models/world/track_2/profile.tres",
	"res://models/world/track_3/profile.tres",
	"res://models/world/track_4/profile.tres",
]
var hud: Control
var art := Art.new()
var screen := "start"
var pending_course := 0
var last_state := ""
var curves: Dictionary = {}


func _init(owner: Control) -> void:
	hud = owner


func area() -> Rect2:
	return hud.top_hud_bounds()


func sync() -> void:
	var race: Node3D = hud.race
	if race.state != last_state:
		if race.state == State.COURSES:
			pending_course = clampi(race.menu_focus, 0, 4)
		last_state = race.state
	if race.passport_open:
		screen = "tour_passport"
	else:
		match race.state:
			State.MENU:
				screen = "start_passport"
			State.COURSES:
				if race.menu_focus in range(5):
					pending_course = race.menu_focus
				screen = "track_select" if pending_course < 2 else "track_select_more"
			State.READY:
				screen = "car_select"
			State.SETTINGS:
				screen = "controls_settings" if hud.controls_open else "settings"
			State.PAUSED:
				screen = "pause"
			State.FINISHED, State.FAILED:
				screen = (
					"result_time_over"
					if race.state == State.FAILED
					else (
						"result_tour"
						if race.mode == "tour"
						else ("result_new_record" if race.new_record else "race_results")
					)
				)
			_:
				screen = "tour_hud" if race.mode == "tour" else "race_hud"


func rect(id: String, from: String = "") -> Rect2:
	return art.rect(screen if from.is_empty() else from, id, area())


func part(id: String, destination: Rect2 = Rect2(), from: String = "", tint: Color = Color.WHITE) -> void:
	var source := screen if from.is_empty() else from
	if not art.index(source).has(id):
		return
	var item: Dictionary = art.index(source)[id].layer
	var bounds := rect(id, source) if not destination.has_area() else destination
	if (
		item.kind in ["card", "button", "modal"]
		or id in ["sound_panel", "music_panel", "graphics_panel", "performance", "controls_panel", "course", "stats"]
	):
		var radius: float = minf(bounds.size.x, bounds.size.y) * .5 if item.get("shape", "") == "ellipse" else 20
		Art.draw_panel(hud, bounds, id in ["tour", "continue", "done", "start_race", "resume", "apply"], radius)

	else:
		assert(item.has("asset"), "설치 목록에 필요한 UI 그림이 없다: %s/%s" % [source, id])
		art.draw_part(hud, source, id, bounds, tint)


func label(bounds: Rect2, value: String, size_px: int = 26, color: Color = Art.WHITE, centered: bool = false) -> void:
	MenuTheme.label(hud, bounds, value, size_px, color, centered, mini(size_px, 19))


func caption(id: String, value: String, size_px: int = 26, inset_left: float = 20, inset_right: float = 20) -> void:
	var bounds := rect(id)
	label(
		Rect2(bounds.position + Vector2(inset_left, 0), bounds.size - Vector2(inset_left + inset_right, 0)),
		value,
		size_px
	)


func panel(bounds: Rect2, color: Color = Art.BLUE, outline: Color = Color.TRANSPARENT, radius: int = 18) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = outline
	style.set_border_width_all(3 if outline.a > 0 else 0)
	hud.draw_style_box(style, bounds)


func button(id: String, value: String, icon: String = "", inset: float = 82, icon_screen: String = "") -> void:
	part(id)
	var content := button_content(id, icon, inset)
	if not icon.is_empty():
		part(icon, content.icon, icon_screen)
	label(content.label, value, 26 if content.stacked else 28, Art.WHITE, content.stacked)


func button_content(id: String, icon: String, inset: float = 20) -> Dictionary:
	var bounds := rect(id)
	var image := rect(icon) if not icon.is_empty() else Rect2()
	var stacked: bool = hud.race.state in State.ENDED and bounds.size.x < 300
	var text := bounds.grow(-12)
	if stacked:
		var ratio := minf(44 / maxf(1, image.size.x), 42 / maxf(1, image.size.y))
		image = Rect2(
			Vector2(bounds.get_center().x - image.size.x * ratio * .5, bounds.position.y + 10), image.size * ratio
		)
		text = Rect2(bounds.position + Vector2(12, 53), Vector2(bounds.size.x - 24, bounds.size.y - 62))
	else:
		var left := inset
		var right := 16.0
		if image.has_area():
			if image.get_center().x < bounds.get_center().x:
				left = maxf(left, image.end.x - bounds.position.x + 14)
			else:
				right = maxf(right, bounds.end.x - image.position.x + 14)
		text = Rect2(bounds.position + Vector2(left, 6), bounds.size - Vector2(left + right, 12))
	return {"icon": image, "label": text, "stacked": stacked}


func header(title: String, icon: String = "header_icon") -> void:
	part("header")
	part("back")
	part("back_icon")
	if art.index(screen).has(icon):
		part(icon)
	var bounds := rect("header")
	label(Rect2(bounds.position + Vector2(358, 6), Vector2(bounds.size.x - 398, 82)), title, 34)
	if art.index(screen).has("settings"):
		part("settings")
		part("settings_icon")


func draw() -> void:
	sync()
	if is_instance_valid(hud.race.tuning_shop):
		art.release()
		return
	art.begin(screen)
	match screen:
		"start", "start_passport":
			draw_home()
		"track_select", "track_select_more":
			draw_courses()
		"car_select":
			draw_garage()
		"settings":
			draw_settings()
		"controls_settings":
			draw_controls_settings()
		"tour_passport":
			draw_passport()
		"pause":
			draw_driving(false)
			draw_pause()
		"race_results", "result_time_over", "result_tour", "result_new_record":
			draw_results()
		_:
			draw_driving(true)
	if hud.pad_on():
		draw_focus()


func draw_home() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	part("brand_header")
	part("settings")
	part("settings_icon")
	# 브랜드도 번역 가능한 글자로 올리고 배경 차는 시작 화면의 장식으로만 사용한다.
	label(Rect2(Vector2(48, 42) + area().position, Vector2(440, 82)), "INITIAL SJ", 64)
	label(Rect2(Vector2(51, 128) + area().position, Vector2(420, 46)), "COAST TO COAST", 24, Art.GOLD)
	button("tour", "TOUR", "", 132)
	var at := rect("tour").position + Vector2(55, 36)
	hud.draw_colored_polygon(PackedVector2Array([at, at + Vector2(0, 42), at + Vector2(38, 21)]), Art.WHITE)
	button("track", "TRACK", "track_icon", 132)
	part("passport", home_passport_rect(), "start_passport")
	part("passport_icon", rect("passport_icon", "start_passport"), "start_passport")
	label(Rect2(area().end - Vector2(258, 40), Vector2(240, 26)), hud.AppVersion.label(), 17, Art.WHITE, true)


func home_passport_rect() -> Rect2:
	return rect("passport", "start_passport")


func course_start() -> int:
	return clampi(pending_course - 1, 0, 2)


func course_rect(index: int) -> Rect2:
	var slot := index - course_start()
	return rect("course_%d" % slot) if slot in range(3) else Rect2()


func draw_courses() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	header("CHOOSE TRACK")
	for slot in range(3):
		var index := course_start() + slot
		var bounds := rect("course_%d" % slot)
		# 기본 카드는 선택 테두리가 없는 동일 부품으로 공유한다.
		Art.draw_panel(hud, bounds, false, 20)
		var photo_screen := "track_select" if index < 3 else "track_select_more"
		var photo_slot := index if index < 3 else index - 2
		part("course_photo_%d" % photo_slot, rect("course_photo_%d" % slot), photo_screen)
		if index == pending_course:
			panel(bounds.grow(1), Color.TRANSPARENT, Art.GOLD, 24)
			part(
				"selected_course",
				Rect2(bounds.position + Vector2(bounds.size.x - 72, 18), Vector2(52, 52)),
				"track_select"
			)
		var lower := Rect2(bounds.position + Vector2(18, bounds.size.y - 92), Vector2(bounds.size.x - 122, 46))
		label(lower, TITLES[index], 24)
		label(
			Rect2(lower.position + Vector2(0, 43), Vector2(lower.size.x, 30)),
			hud.race.tr("CIRCUIT %02d") % (index + 1),
			18,
			Art.GOLD
		)
		draw_course_outline(index, Rect2(bounds.end - Vector2(101, 86), Vector2(78, 57)))
	part("previous")
	part("previous_icon")
	part("next")
	part("next_icon")
	for i in range(5):
		hud.draw_circle(Vector2(570 + i * 35, 544), 8, Art.GOLD if i == pending_course else Art.WHITE)
	button(
		"weather",
		hud.race.track_environment.weather.to_upper(),
		"weather_icon",
		112,
		"track_conditions" if hud.race.track_environment.weather == "rain" else screen
	)
	button(
		"time",
		hud.race.track_environment.time_of_day.to_upper(),
		"time_icon",
		102,
		"track_conditions" if hud.race.track_environment.time_of_day == "night" else screen
	)
	button("continue", "CONTINUE", "continue_icon", 28)


func course_points(index: int) -> PackedVector2Array:
	if not curves.has(index):
		var resource: Resource = load(COURSE_PROFILES[index])
		var curve: Curve3D = resource.get_meta("profile").curve
		var samples := PackedVector2Array()
		for i in range(97):
			var point := curve.sample_baked(curve.get_baked_length() * i / 96.0)
			samples.append(Vector2(point.x, point.z))
		curves[index] = samples
	return curves[index]


func draw_course_outline(index: int, bounds: Rect2) -> void:
	var samples := course_points(index)
	var source := Rect2(samples[0], Vector2.ZERO)
	for point in samples:
		source = source.expand(point)
	var ratio := minf(bounds.size.x / maxf(source.size.x, 1), bounds.size.y / maxf(source.size.y, 1))
	var line := PackedVector2Array()
	for point in samples:
		line.append(bounds.get_center() + (point - source.get_center()) * ratio)
	hud.draw_polyline(line, Art.WHITE, 3, true)


func garage_card(index: int) -> Rect2:
	var first := clampi(hud.race.selected_vehicle - 2, 0, maxi(0, Catalog.SPECS.size() - 5))
	return (
		rect("vehicle_card_%d" % (index - first), "car_select")
		if index in range(first, mini(first + 5, Catalog.SPECS.size()))
		else Rect2()
	)


func car(index: int, destination: Rect2) -> void:
	var previews: Node = hud.race.previews
	if previews == null or not destination.has_area():
		return
	previews.show_vehicle(index)
	var image: Texture2D = previews.textures[index]
	var size_px := image.get_size()
	size_px *= minf(destination.size.x / size_px.x, destination.size.y / size_px.y)
	hud.draw_texture_rect(image, Rect2(destination.get_center() - size_px * .5, size_px), false)


func draw_garage() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	header("CHOOSE A CAR", "")
	part("previous_vehicle")
	part("previous_vehicle_icon")
	part("next_vehicle")
	part("next_vehicle_icon")
	car(hud.race.selected_vehicle, Rect2(172, 147, 575, 250))
	label(Rect2(220, 364, 520, 48), hud.race.vehicle.name, 31, Art.WHITE, true)
	part("performance")
	for i in range(4):
		var row := rect("performance_%d" % i)
		# 공통 아이콘만 잘라 쓰고 성능 바는 저장된 실제 수치를 그린다.
		art.draw_fragment(
			hud,
			screen,
			"performance_%d_icon" % i,
			Rect2(
				0, 0, 88, art.source_rect(screen, "performance_%d_icon" % i).size.y * Art.screen_size(screen).y / 720
			),
			Rect2(row.position, Vector2(68, row.size.y))
		)
		var amount: float = hud.shown_abilities[i] if hud.shown_abilities.size() == 4 else 0
		for level in range(5):
			panel(
				Rect2(row.position + Vector2(99 + level * 42, 20), Vector2(37, 16)),
				Art.GOLD if level < roundi(amount) else Art.WHITE,
				Color.TRANSPARENT,
				5
			)
	for index in range(Catalog.SPECS.size()):
		var bounds := garage_card(index)
		if not bounds.has_area():
			continue
		part("vehicle_card_0", bounds)
		if index == hud.race.selected_vehicle:
			panel(bounds, Color.TRANSPARENT, Art.GOLD, 20)
		car(index, bounds.grow(-8))
	button("tuning", "TUNING SHOP", "tuning_icon", 114)
	button("start_race", "START RACE", "start_race_icon", 28)
	if hud.garage_notice_left > 0:
		label(Rect2(350, 558, 580, 34), hud.garage_notice, 21, Art.GOLD, true)


func draw_toggle(id: String, enabled: bool, from: String = "") -> void:
	var bounds := rect(id, from)
	panel(bounds, Art.GOLD if enabled else Art.BLUE.lightened(.2), Color.TRANSPARENT, 20)
	var radius := bounds.size.y * .34
	hud.draw_circle(
		Vector2(bounds.end.x - radius - 7 if enabled else bounds.position.x + radius + 7, bounds.get_center().y),
		radius,
		Art.WHITE
	)


func slider_rect(music: bool) -> Rect2:
	var normal := rect("music_volume" if music else "sound_volume", "settings")
	return Rect2(normal.position + Vector2(0, -12), Vector2(normal.size.x, 80))


func draw_settings() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	header("SETTINGS", "settings_icon")
	for id in ["sound_panel", "music_panel", "sound_icon", "music_icon", "graphics_panel", "graphics_icon"]:
		part(id)
	# 패널 제목은 위쪽, 볼륨은 아래쪽으로 분리한다.
	for music in [false, true]:
		var bounds := rect("music_panel" if music else "sound_panel")
		label(Rect2(bounds.position + Vector2(128, 18), Vector2(278, 64)), "MUSIC" if music else "SOUND EFFECTS", 26)
		draw_toggle(
			"music_toggle" if music else "sound_toggle", hud.race.music_enabled if music else hud.race.sound_enabled
		)
		var volume: int = hud.race.audio_preferences.music_volume if music else hud.race.audio_preferences.sound_volume
		draw_slider(slider_rect(music), volume)
	label(Rect2(rect("graphics_panel").position + Vector2(113, 12), Vector2(400, 50)), "GRAPHICS", 26)
	for i in range(3):
		var bounds := rect("graphics_%d" % i)
		part("graphics_%d" % i)
		if i == hud.race.graphics_mode:
			panel(bounds.grow(-3), Color.TRANSPARENT, Art.GOLD, 17)
		part("graphics_%d_icon" % i, Rect2(bounds.get_center().x - 46, bounds.position.y + 8, 92, 53))
		label(
			Rect2(bounds.position + Vector2(8, bounds.size.y - 35), Vector2(bounds.size.x - 16, 30)),
			["AUTO", "HIGH", "PERFORMANCE"][i],
			21,
			Art.WHITE,
			true
		)
	for id in ["motion", "fps", "auto_acceleration"]:
		part(id)
		var bounds := rect(id)
		var enabled: bool = (
			hud.race.motion_reduced
			if id == "motion"
			else (hud.race.show_fps if id == "fps" else hud.race.auto_accelerate)
		)
		var title := "REDUCED MOTION" if id == "motion" else ("SHOW FPS" if id == "fps" else "AUTO ACCELERATE")
		var icon_id: String = id + "_icon"
		var values: Array = Art.data().assets[art.index(screen)[icon_id].layer.asset].size
		art.draw_fragment(
			hud, screen, icon_id, Rect2(0, 0, 74, values[1]), Rect2(bounds.position + Vector2(18, 17), Vector2(52, 40))
		)
		var switch := Rect2(bounds.end.x - 78, bounds.get_center().y - 18, 64, 36)
		panel(switch, Art.GOLD if enabled else Art.BLUE.lightened(.2), Color.TRANSPARENT, 18)
		hud.draw_circle(
			Vector2(switch.end.x - 19 if enabled else switch.position.x + 19, switch.get_center().y), 13, Art.WHITE
		)
		if id == "auto_acceleration":
			label(Rect2(bounds.position + Vector2(92, 5), Vector2(bounds.size.x - 186, bounds.size.y - 10)), title, 24)
		else:
			label(
				Rect2(bounds.position + Vector2(12, bounds.size.y - 34), Vector2(bounds.size.x - 24, 29)),
				title,
				21,
				Art.WHITE,
				true
			)
	button("controls", "CONTROLS", "controls_icon", 150)
	button("done", "DONE", "done_icon", 28)
	if OS.has_feature("web"):
		for i in range(2):
			var bounds := web_rect(i)
			panel(bounds, Art.BLUE)
			label(bounds.grow(-8), "FULLSCREEN" if i == 0 else "INSTALL", 21, Art.WHITE, true)


func draw_slider(bounds: Rect2, value: int) -> void:
	var start := bounds.position + Vector2(12, bounds.size.y * .5)
	var end := Vector2(bounds.end.x - 70, start.y)
	var knob := start.lerp(end, value / 100.0)
	hud.draw_line(start, end, Art.WHITE.darkened(.32), 9, true)
	hud.draw_line(start, knob, Art.GOLD, 9, true)
	hud.draw_circle(knob, 15, Art.GOLD)
	hud.draw_circle(knob, 11, Art.WHITE)
	label(Rect2(bounds.end - Vector2(61, bounds.size.y), Vector2(61, bounds.size.y)), "%d" % value, 24, Art.WHITE, true)


func web_rect(index: int) -> Rect2:
	return Rect2(396 + index * 260, 116, 248, 64)


func draw_controls_settings() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	header("CONTROLS", "controls_icon")
	part("controls_panel")
	for i in range(2):
		var id := "steering_left" if i == 0 else "steering_right"
		part(id)
		if hud.race.touch_layout.mirrored == (i == 1):
			panel(rect(id).grow(-4), Color.TRANSPARENT, Art.GOLD)
		var bounds := rect(id)
		part(id + "_icon", Rect2(bounds.get_center().x - 145, bounds.position.y + 8, 290, 86))
		label(
			Rect2(bounds.position + Vector2(12, bounds.size.y - 43), Vector2(bounds.size.x - 24, 36)),
			"STEER LEFT" if i == 0 else "STEER RIGHT",
			25,
			Art.WHITE,
			true
		)
	for i in range(3):
		var id := "size_%d" % i
		part(id)
		if hud.race.touch_layout.size_index == i:
			panel(rect(id).grow(-4), Color.TRANSPARENT, Art.GOLD)
		var bounds := rect(id)
		var diameter: float = [22, 34, 46][i]
		part(
			id + "_icon",
			Rect2(bounds.get_center().x - diameter * .5, bounds.position.y + 28 - diameter * .5, diameter, diameter)
		)
		label(
			Rect2(bounds.position + Vector2(10, bounds.size.y - 44), Vector2(bounds.size.x - 20, 40)),
			["SMALL", "MEDIUM", "LARGE"][i],
			23,
			Art.WHITE,
			true
		)
	var preview := rect("controls_preview")
	panel(preview, Color("294c62"))
	car(hud.race.selected_vehicle, Rect2(preview.position + Vector2(290, 5), Vector2(350, preview.size.y - 65)))
	var left := preview.position + Vector2(90 if not hud.race.touch_layout.mirrored else preview.size.x - 90, 84)
	var scale_factor: float = hud.race.touch_layout.SIZES[hud.race.touch_layout.size_index]
	hud.draw_circle(left, 58 * scale_factor, Color("456c83"))
	hud.draw_circle(left, 23 * scale_factor, Art.WHITE)
	var pedals_x: float = preview.position.x + (100 if hud.race.touch_layout.mirrored else preview.size.x - 100)
	for i in range(3):
		var center := Vector2(
			pedals_x + (-48 if i == 0 else (48 if i == 1 else 0)), preview.position.y + (65 if i < 2 else 150)
		)
		var size_px := Vector2.ONE * 57 * scale_factor
		var action: String = ["drift", "nitro", "brake"][i]
		part(action, Rect2(center - size_px * .5, size_px), "race_hud")
		part(action + "_icon", Rect2(center - size_px * .27, size_px * .54), "race_hud")
	var ghost := ghost_rect()
	panel(ghost, Art.BLUE, Art.GOLD if hud.race.show_ghost else Color.TRANSPARENT)
	label(ghost.grow(-8), "GHOST: ON" if hud.race.show_ghost else "GHOST: OFF", 22, Art.WHITE, true)
	button("reset", "RESET", "reset_icon", 114)
	button("done", "DONE", "done_icon", 28)


func ghost_rect() -> Rect2:
	var preview := rect("controls_preview", "controls_settings")
	return Rect2(preview.get_center() + Vector2(-140, 27), Vector2(280, 74))


func draw_passport() -> void:
	art.background(hud, screen, Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()))
	header("TOUR PASSPORT", "passport_icon")
	var passport: RefCounted = hud.race.passport
	var progress := rect("passport_progress")
	panel(progress.grow(12), Art.BLUE)
	label(
		Rect2(progress.position, Vector2(progress.size.x, 34)),
		hud.race.tr("%d / 5 GOALS") % passport.goals.size(),
		23,
		Art.WHITE,
		true
	)
	hud.draw_rect(
		Rect2(progress.position + Vector2(16, 37), Vector2((progress.size.x - 32) * passport.goals.size() / 5.0, 4)),
		Art.GOLD
	)
	for i in range(5):
		var theme: String = Library.THEMES[4][i]
		part("goal_%d" % i)
		part("goal_photo_%d" % i)
		var bounds := rect("goal_%d" % i)
		var medal: int = passport.goals.get(theme, 0)
		label(
			Rect2(bounds.position + Vector2(8, 115), Vector2(bounds.size.x - 16, 44)),
			Library.TITLES[theme],
			23,
			Art.WHITE,
			true
		)
		label(rect("goal_medal_%d" % i), Challenge.medal_label(medal) if medal > 0 else "UNVISITED", 21, Art.GOLD, true)
	for i in range(16):
		var route := ""
		for bit in range(4):
			route += "R" if (i >> bit) & 1 else "L"
		part("route_%d" % i)
		var medal: int = passport.routes.get(route, 0)
		label(
			rect("route_%d" % i).grow(-6),
			route + "   " + hud.race.tr(Challenge.medal_label(medal)),
			22,
			Art.GOLD if medal > 0 else Art.WHITE,
			true
		)
	var unlocked: Array[int] = passport.unlocked_paints()
	for i in range(passport.PAINTS.size()):
		var bounds := rect("reward_%d" % i)
		part("reward_%d" % i)
		var color := Color("b6c3cd") if i == 0 else Color(passport.PAINTS[i].color)
		hud.draw_circle(bounds.position + Vector2(30, 30), 14, color)
		label(Rect2(bounds.position + Vector2(54, 6), Vector2(bounds.size.x - 66, 36)), passport.PAINTS[i].name, 21)
		hud.menu_text.draw_wrapped(
			Rect2(bounds.position + Vector2(12, 43), Vector2(bounds.size.x - 24, 50)),
			hud.race.tr("UNLOCKED" if i in unlocked else passport.PAINTS[i].goal),
			19,
			Art.GOLD if i in unlocked else Art.WHITE
		)


func draw_driving(active: bool) -> void:
	var layout: Dictionary = hud.top_hud_rects()
	for id in ["pause", "course", "stats"]:
		part(id, layout[id], "race_hud")
	part("pause_icon", Rect2(layout.pause.position + Vector2(20, 15), Vector2(24, 32)), "race_hud")
	var race: Node3D = hud.race
	var course: Rect2 = layout.course
	var course_title: String = (
		race.course_title if race.mode == "track" else Library.title(race.stage_index, race.route_node)
	)
	label(Rect2(course.position + Vector2(12, 3), Vector2(course.size.x - 24, 30)), course_title, 21)
	label(
		Rect2(course.position + Vector2(12, 31), Vector2(course.size.x - 24, 22)),
		hud.race.tr("CIRCUIT %02d") % (race.selected_course + 1) if race.mode == "track" else "TOUR",
		14,
		Art.GOLD
	)
	var stats: Rect2 = layout.stats
	var track: bool = race.mode == "track"
	var values := [
		"%d / %d" % [race.race_position(), race.competitor_count()] if track else "%d / 5" % (race.stage_index + 1),
		"%d / 3" % mini(3, race.laps_completed + 1) if track else str(maxi(0, ceili(race.time_left))),
		hud.time_label(race.elapsed)
	]
	var titles := ["POS", "LAP", "RACE TIME"] if track else ["STAGE", "TIME LEFT", "TOTAL TIME"]
	var widths := [.25, .25, .5]
	var left := stats.position.x
	for i in range(3):
		var width: float = stats.size.x * widths[i]
		label(Rect2(left + 12, stats.position.y, width - 20, 23), titles[i], 14, Color("d5e4ed"))
		label(Rect2(left + 12, stats.position.y + 21, width - 20, 37), values[i], 26, Art.GOLD if i == 0 else Art.WHITE)
		left += width
	if track and race.state == State.RACING and race.circuit_checkpoint >= 0:
		var remaining := Rect2(Vector2(course.end.x - 230, course.end.y + 8), Vector2(230, 40))
		panel(remaining, Art.BLUE)
		label(
			remaining.grow(-4),
			race.tr("TIME LEFT %ds") % maxi(0, ceili(race.time_left)),
			22,
			Art.GOLD if race.time_left < 15 else Art.WHITE,
			true
		)
	# 경로와 주변 차량은 원화의 예시가 아니라 현재 경기의 미니맵을 그린다.
	hud.draw_minimap()
	var speed_bounds := Rect2(area().position.x + 28, 278, 220, 84)
	label(Rect2(speed_bounds.position, Vector2(146, 58)), str(int(race.speed * 3.6)), 44)
	label(Rect2(speed_bounds.position + Vector2(141, 20), Vector2(80, 32)), "KM/H", 17, Art.GOLD)
	var gear := "N" if race.gear_number() == 0 else ("R" if race.gear_number() < 0 else str(race.gear_number()))
	label(Rect2(speed_bounds.position + Vector2(0, 56), Vector2(196, 28)), hud.race.tr("GEAR") + "  " + gear, 18)
	hud.configure_pedals()
	var bottom: float = area().end.y - 720
	var resting: Vector2 = hud.steering_rest()
	var center: Vector2 = hud.joystick.origin if hud.joystick.active() else resting
	var radius: float = hud.HudLayout.STICK_RADIUS * race.touch_layout.SIZES[race.touch_layout.size_index]
	hud.draw_circle(center, radius, Color("355d77dc"))
	hud.draw_arc(center, radius, 0, TAU, 48, Color("94b2c4"), 2, true)
	var knob: Vector2 = center + hud.joystick.offset if hud.joystick.active() else center
	hud.draw_circle(knob, 34, Color("c5d7e2"))
	hud.draw_arc(knob, 34, PI, TAU, 24, Art.WHITE, 1.5, true)
	for action in ["drift", "nitro", "brake", "gas", "cell"]:
		if action == "gas" and race.auto_accelerate or action == "cell" and race.vehicle.mode != "hybrid":
			continue
		var bounds: Rect2 = hud.buttons[action]
		var source: String = action if action in ["drift", "nitro", "brake"] else "nitro"
		part(source, bounds, "race_hud")
		if action == "nitro" and hud.nitro_ready():
			hud.draw_arc(bounds.get_center(), bounds.size.x * .52, 0, TAU, 48, Art.GOLD, 3, true)
		if action == "gas":
			label(bounds.grow(-10), "GAS", 25, Art.WHITE, true)
		elif action == "cell":
			label(
				Rect2(bounds.position + Vector2(6, 16), Vector2(bounds.size.x - 12, 38)),
				str(race.nitro_charges),
				29,
				Art.GOLD,
				true
			)
			label(Rect2(bounds.position + Vector2(6, 57), Vector2(bounds.size.x - 12, 30)), "CELL", 19, Art.WHITE, true)
			if race.shot_recharge > 0:
				hud.draw_arc(
					bounds.get_center(),
					bounds.size.x * .46,
					-PI / 2,
					-PI / 2 + TAU * race.shot_recharge / 100,
					40,
					Art.GOLD,
					4,
					true
				)
		else:
			part(action + "_icon", Rect2(bounds.position + bounds.size * .23, bounds.size * .54), "race_hud")
	var gauge := Rect2(421, 650 + bottom, 440, 44)
	part("nitro_gauge", gauge, "race_hud")
	# 원화의 고정 채움 대신 실제 충전량·연속형/충전형 슬롯을 표시한다.
	panel(gauge.grow(-4), Color("263e51"), Color.TRANSPARENT, 9)
	if race.vehicle.mode == "charges":
		for i in range(3):
			var cell := Rect2(gauge.position + Vector2(15 + i * 137, 12), Vector2(128, 19))
			var amount: float = (
				1.0 if i < race.nitro_charges else (race.shot_recharge / 100.0 if i == race.nitro_charges else 0.0)
			)
			panel(cell, Color("142b3d"), Color.TRANSPARENT, 5)
			if amount > 0:
				panel(Rect2(cell.position, Vector2(cell.size.x * amount, cell.size.y)), Art.GOLD, Color.TRANSPARENT, 5)
	else:
		panel(
			Rect2(gauge.position + Vector2(15, 12), Vector2(410 * race.nitro / 100, 19)), Art.GOLD, Color.TRANSPARENT, 5
		)
	if not active:
		return
	hud.draw_fps()
	hud.draw_competitor_markers()
	hud.draw_slipstream_target()
	hud.draw_pace_feedback()
	hud.draw_drift_score()
	hud.draw_route_choice()
	hud.draw_recovery()
	preload("res://scripts/ui/driving_challenges_ui.gd").draw_split(hud)
	if race.protection_left > 0 and race.state == State.RACING:
		var bounds := Rect2(area().position + Vector2(20, 148), Vector2(270, 44))
		panel(bounds, Art.BLUE)
		label(bounds.grow(-6), hud.race.tr("INVINCIBLE  %.1fs") % race.protection_left, 22, Art.WHITE, true)
	if race.state == State.COUNTDOWN:
		draw_countdown()


func draw_countdown() -> void:
	var rolling: bool = hud.race.mode == "track" and hud.race.selected_course == 1
	var from := "rolling_start" if rolling else "start_countdown"
	var seconds := ceili(hud.race.countdown)
	var frame := rect("start_signal", from)
	part("start_signal", frame, from)
	var centers := [Vector2(.22, .5), Vector2(.5, .5), Vector2(.78, .5)]
	var radius: float = frame.size.y * .305
	var active := clampi((6 if rolling else 4) - seconds, 0, 3)
	for i in range(3):
		var center: Vector2 = frame.position + centers[i] * frame.size
		hud.draw_circle(center, radius + 3, Art.BLUE)
		if i < active:
			hud.draw_circle(center, radius + 7, Color("ec826133"))
			hud.draw_circle(center, radius, Color("ee8769"))
			hud.draw_circle(center, radius * .7, Color("f39c78"))
		hud.draw_arc(center, radius, 0, TAU, 48, Art.WHITE if i < active else Color("b9d0dc"), 2.5, true)
	var value := rect("rolling_status" if rolling else "countdown_value", from)
	part("rolling_status" if rolling else "countdown_value", value, from)
	label(value, hud.race.tr("ROLLING START") + "  %d" % seconds if rolling else str(seconds), 27, Art.WHITE, true)


func draw_pause() -> void:
	# 중계 화면을 그대로 두고 작은 팝업만 올린다.
	part("pause_dialog")
	part("pause_title_icon")
	label(Rect2(rect("pause_dialog").position + Vector2(110, 12), Vector2(400, 60)), "RACE PAUSED", 32)
	button("resume", "RESUME", "resume_icon", 100)
	button("settings", "SETTINGS", "settings_icon", 82)
	button("retry", "RETRY", "retry_icon", 82)
	button("home", hud.race.result_button_label(), "home_icon", 100)


func draw_results() -> void:
	var race: Node3D = hud.race
	if race.result_age < 1.2:
		return
	part("result_panel")
	part("result_header")
	var bounds := rect("result_panel")
	var place: int = race.race_position()
	var heading := (
		"TIME OVER"
		if race.state == State.FAILED
		else ("GOAL CLEAR!" if race.mode == "tour" else ("1ST PLACE" if place == 1 else "RACE FINISHED"))
	)
	if race.new_record and race.state == State.FINISHED:
		heading = "NEW RECORD!"
	label(Rect2(bounds.position + Vector2(28, 66), Vector2(bounds.size.x - 56, 56)), heading, 31, Art.GOLD, true)
	var detail: String = (
		race.tr("POS %d / %d") % [place, race.competitor_count()]
		if race.mode == "track"
		else race.tr("ROUTE %s") % race.TourChallenge.route_id(race.track.history)
	)
	label(
		Rect2(bounds.position + Vector2(28, 126), Vector2(bounds.size.x - 56, 35)),
		detail + "  /  " + race.vehicle.name,
		21,
		Art.WHITE,
		true
	)
	var values := [
		hud.time_label(race.elapsed),
		hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---",
		str(int(race.score))
	]
	var titles := ["RUN TIME", "BEST TIME", "SCORE"]
	for i in range(3):
		var top: float = bounds.position.y + 174 + i * 44
		label(Rect2(bounds.position.x + 27, top, 175, 36), titles[i], 21)
		label(Rect2(bounds.position.x + 198, top, bounds.size.x - 223, 36), values[i], 27, Art.GOLD, true)
	var technique: String = (
		race.TourChallenge.medal_label(race.run_medal) + "  /  " + race.tr("DRIFT x%d") % race.max_drift_multiplier
	)
	label(Rect2(bounds.position + Vector2(26, 310), Vector2(bounds.size.x - 52, 30)), technique, 21, Art.GOLD, true)
	label(
		Rect2(bounds.position + Vector2(26, 341), Vector2(bounds.size.x - 52, 28)),
		(
			race.tr("PASS x%d  |  HITS %d  |  RESET %d")
			% [race.rewards.max_pass_chain, race.wall_hits + race.traffic_hits, race.personal_run.recoveries]
		),
		18,
		Art.WHITE,
		true
	)
	if not race.passport.new_unlocks.is_empty():
		label(
			Rect2(bounds.position + Vector2(26, 370), Vector2(bounds.size.x - 52, 26)),
			race.tr("UNLOCK: %s") % race.passport.new_unlocks[0],
			20,
			Art.GOLD,
			true
		)
	var target: String = preload("res://scripts/ui/driving_challenges_ui.gd").result_target(race)
	label(Rect2(bounds.position + Vector2(26, 398), Vector2(bounds.size.x - 52, 26)), target, 18, Art.WHITE, true)
	button("retry", "RETRY", "retry_icon", 90)
	button("continue", race.result_button_label(), "continue_icon", 28)


func press(pos: Vector2, pointer: int) -> bool:
	sync()
	var race: Node3D = hud.race
	if race.passport_open:
		if hit("back", pos):
			race.toggle_passport()
		return true
	match race.state:
		State.MENU:
			if home_passport_rect().has_point(pos):
				race.toggle_passport()
			elif hit("tour", pos):
				race.navigate_to_mode("tour")
			elif hit("track", pos):
				race.navigate(race.open_courses)
			elif hit("settings", pos):
				race.navigate(race.open_settings)
		State.COURSES:
			if hit("back", pos):
				race.navigate(race.open_menu)
			elif hit("settings", pos):
				race.navigate(race.open_settings)
			elif hit("continue", pos):
				race.navigate_to_mode("track", pending_course)
			elif hit("weather", pos):
				race.cycle_track_weather()
			elif hit("time", pos):
				race.cycle_track_period()
			elif hit("previous", pos):
				select_course(posmod(pending_course - 1, 5))
			elif hit("next", pos):
				select_course(posmod(pending_course + 1, 5))
			else:
				for i in range(5):
					if course_rect(i).has_point(pos):
						select_course(i)
		State.READY:
			if hit("back", pos):
				race.navigate(race.open_courses if race.mode == "track" else race.open_menu)
			elif hit("settings", pos):
				race.navigate(race.open_settings)
			elif hit("tuning", pos):
				race.open_tuning()
			elif hit("start_race", pos):
				race.start_race()
			elif hit("previous_vehicle", pos):
				race.select_vehicle(posmod(race.selected_vehicle - 1, Catalog.SPECS.size()))
			elif hit("next_vehicle", pos):
				race.select_vehicle((race.selected_vehicle + 1) % Catalog.SPECS.size())
			else:
				for i in range(Catalog.SPECS.size()):
					if garage_card(i).has_point(pos):
						race.select_vehicle(i)
		State.SETTINGS:
			if hud.controls_open:
				press_controls(pos)
			elif Audio.begin_drag(hud, pointer, pos):
				pass
			elif hit("back", pos) or hit("done", pos):
				race.close_settings()
			elif hit("sound_toggle", pos):
				race.toggle_sound()
			elif hit("music_toggle", pos):
				race.toggle_music()
			elif hit("motion", pos):
				race.toggle_motion()
			elif hit("fps", pos):
				race.toggle_fps()
			elif hit("auto_acceleration", pos):
				race.toggle_auto_accelerate()
			elif hit("controls", pos):
				hud.open_controls()
			else:
				for i in range(3):
					if hit("graphics_%d" % i, pos):
						race.graphics_mode = i
						race.render_budget.set_mode(i, race)
						race.save_preferences()
				if OS.has_feature("web"):
					if web_rect(0).has_point(pos):
						race.shell.toggle_fullscreen()
					elif web_rect(1).has_point(pos):
						hud.install_game()
		State.PAUSED:
			if hit("resume", pos) or hud.pause_touch_rect().has_point(pos):
				race.resume_tour()
			elif hit("settings", pos):
				race.open_settings()
			elif hit("retry", pos):
				race.start_race()
			elif hit("home", pos):
				race.navigate(race.open_courses if race.mode == "track" else race.open_menu)
		State.FINISHED, State.FAILED:
			if race.result_age >= 1.2:
				if hit("retry", pos):
					race.start_race()
				elif hit("continue", pos):
					race.leave_results()
		_:
			return false
	return true


func select_course(index: int) -> void:
	pending_course = index
	hud.race.menu_focus = index


func press_controls(pos: Vector2) -> void:
	var race: Node3D = hud.race
	if hit("back", pos) or hit("done", pos):
		hud.controls_open = false
		race.save_preferences()
	elif hit("reset", pos):
		race.touch_layout.reset()
		race.save_preferences()
	elif ghost_rect().has_point(pos):
		race.toggle_ghost()
	else:
		for i in range(2):
			if hit("steering_left" if i == 0 else "steering_right", pos):
				race.touch_layout.mirrored = i == 1
				race.save_preferences()
		for i in range(3):
			if hit("size_%d" % i, pos):
				race.touch_layout.size_index = i
				race.save_preferences()


func hit(id: String, pos: Vector2) -> bool:
	return touch_rect(id).has_point(pos)


func touch_rect(id: String) -> Rect2:
	var bounds := rect(id)
	if not bounds.has_area():
		return bounds
	# 작은 휴대폰에서도 44px 이상. 주변 버튼의 중심선은 넘지 않는 개별 영역을 사용한다.
	var minimum: float = maxf(80, 44.0 / hud.ui_scale())
	return Rect2(
		bounds.get_center() - bounds.size.max(Vector2.ONE * minimum) * .5, bounds.size.max(Vector2.ONE * minimum)
	)


func press_rects() -> Array[Rect2]:
	sync()
	var result: Array[Rect2] = []
	for id in art.index(screen):
		var item: Dictionary = art.index(screen)[id].layer
		if item.has("action") and item.kind in ["button", "icon_button", "card"]:
			result.append(rect(id))
	return result


func draw_focus() -> void:
	if hud.race.state in [State.MENU, State.COURSES]:
		hud.draw_pad_focus()
	elif hud.race.state == State.SETTINGS:
		var targets: Array[Rect2] = []
		if hud.controls_open:
			targets.assign(
				[
					rect("steering_right" if hud.race.touch_layout.mirrored else "steering_left"),
					rect("size_%d" % hud.race.touch_layout.size_index),
					ghost_rect(),
					rect("reset"),
					rect("done")
				]
			)
		else:
			for id in [
				"sound_panel", "music_panel", "motion", "graphics_panel", "fps", "auto_acceleration", "controls"
			]:
				targets.append(rect(id))
			if OS.has_feature("web"):
				targets.append_array([web_rect(0), web_rect(1)])
			targets.append(rect("done"))
		panel(targets[clampi(hud.race.settings_focus, 0, targets.size() - 1)].grow(2), Color.TRANSPARENT, Art.GOLD)
