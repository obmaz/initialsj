extends RefCounted
# 밝은 해안 메뉴를 그린다. 입력 판정은hud.gd의 같은 사각형을 사용한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const PreRaceArt = preload("res://scripts/ui/pre_race_art.gd")
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const COURSE_PREVIEWS := [
	"res://assets/ui/courses/fuji.tres",
	"res://assets/ui/courses/speedway.tres",
	"res://assets/ui/courses/night.tres",
	"res://assets/ui/courses/riviera.tres",
	"res://assets/ui/courses/gorge.tres"
]
const TOUR_PREVIEW := "res://assets/ui/courses/tour.tres"
const HOME_BG := "res://assets/ui/pre_race/home.png"
const GARAGE_BG := "res://assets/ui/pre_race/garage.png"
var menu_art: Dictionary = {}
var menu_art_requested := false
var active_screen := ""
var retired_art: Array[Texture2D] = []
var hud: Control
var race: Node3D:
	get:
		return hud.race


func _init(owner: Control) -> void:
	hud = owner


func art(path: String) -> Texture2D:
	if not menu_art.has(path):
		menu_art[path] = RenderResources.fetch(path)
	return menu_art[path]


func sync_menu_art() -> void:
	# 직전 프레임의 그리기 명령을 교체한 뒤 이전 화면 참조를 해제한다.
	retired_art.clear()
	if race.state in RaceState.DRIVING:
		if menu_art_requested or not menu_art.is_empty():
			menu_art_requested = false
			active_screen = ""
			menu_art.clear()
			for path in (
				COURSE_PREVIEWS
				+ [HOME_BG, GARAGE_BG, TOUR_PREVIEW, MenuTheme.HEADER_ART, MenuTheme.PRIMARY_ART]
				+ PreRaceArt.paths()
			):
				RenderResources.release(path)
		return
	var screen: String = (
		{
			RaceState.MENU: "home",
			RaceState.COURSES: "courses",
			RaceState.READY: "garage",
			RaceState.SETTINGS: "settings"
		}
		. get(race.state, "")
	)
	if screen != active_screen:
		if not active_screen.is_empty():
			var old: String = PreRaceArt.FILES[active_screen]
			if menu_art.has(old) and DisplayServer.get_name() != "headless":
				retired_art.append(menu_art[old])
			menu_art.erase(old)
			RenderResources.release(old)
		active_screen = screen
		if not screen.is_empty():
			RenderResources.warm(PreRaceArt.FILES[screen])
	if not menu_art_requested and not screen.is_empty():
		menu_art_requested = true
		for path in COURSE_PREVIEWS + [TOUR_PREVIEW, MenuTheme.HEADER_ART, MenuTheme.PRIMARY_ART]:
			RenderResources.warm(path)


func draw_home() -> void:
	PreRaceArt.background(hud, "home")
	MenuTheme.label(hud, Rect2(320, 12, 600, 82), "INITIAL SJ", 64, MenuTheme.INK, true)
	if race.previews != null:
		hud.draw_texture_rect(race.previews.textures[2], Rect2(40, 230, 410, 201), false)
		hud.draw_texture_rect(race.previews.textures[1], Rect2(830, 230, 410, 201), false)
		hud.draw_texture_rect(race.previews.textures[0], Rect2(350, 170, 580, 284), false)
	for index in range(2):
		var rect: Rect2 = hud.HOME_TOUR if index == 0 else hud.HOME_TRACK
		MenuTheme.cover(
			hud,
			art(TOUR_PREVIEW if index == 0 else COURSE_PREVIEWS[1]),
			Rect2(rect.end.x - 168, rect.position.y + 20, 148, rect.size.y - 40)
		)
		MenuTheme.label(
			hud, Rect2(rect.position + Vector2(24, 18), Vector2(300, 64)), "TOUR" if index == 0 else "TRACK", 52
		)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(24, 88), Vector2(310, 38)),
			"5 STAGES / 16 ROUTES" if index == 0 else "5 CIRCUITS / 3 LAPS",
			25,
			MenuTheme.TEAL
		)
		hud.draw_line(
			rect.position + Vector2(18, rect.size.y - 12), rect.end - Vector2(176, 12), MenuTheme.YELLOW, 6, true
		)
	MenuTheme.label(hud, Rect2(45, 32, 230, 36), "TOUR PASSPORT", 24, MenuTheme.INK, true)
	MenuTheme.label(
		hud, Rect2(45, 69, 230, 28), race.tr("%d / 5 GOALS") % race.passport.goals.size(), 22, MenuTheme.TEAL, true
	)
	PreRaceArt.button(hud, hud.HOME_SETTINGS, "SETTINGS", 30)
	MenuTheme.label(hud, Rect2(440, 668, 400, 38), hud.AppVersion.label(), 22, MenuTheme.MUTED, true)


func draw_courses() -> void:
	PreRaceArt.background(hud, "courses")
	PreRaceArt.button(hud, hud.GARAGE_BACK, "‹ BACK")
	MenuTheme.label(hud, Rect2(335, 20, 600, 68), "TRACKS", 40)
	var rects := [hud.COURSE_FUJI, hud.COURSE_SPEEDWAY, hud.COURSE_NIGHT, hud.COURSE_RIVIERA, hud.COURSE_GORGE]
	var titles := [
		["FUJI", "LAKESIDE"],
		["SUNCOAST", "SPEEDWAY"],
		["MIDNIGHT", "HARBOR"],
		["AZURE", "RIVIERA"],
		["SCARLET", "GORGE"]
	]
	var lengths := [5.72, 5.76, 2.74, 3.64, 3.54]
	for i in range(5):
		var rect: Rect2 = rects[i]
		var selected: bool = i == (race.menu_focus if hud.pad_on() else race.selected_course)
		PreRaceArt.panel(hud, rect, "panel", selected)
		MenuTheme.cover(
			hud, art(COURSE_PREVIEWS[i]), Rect2(rect.position + Vector2(16, 16), Vector2(rect.size.x - 32, 272))
		)
		var badge := Rect2(rect.position + Vector2(16, 16), Vector2(72, 48))
		PreRaceArt.draw_frame(hud, badge, "primary")
		MenuTheme.label(hud, badge, "%02d" % (i + 1), 22, MenuTheme.INK, true)
		MenuTheme.label(hud, Rect2(rect.position + Vector2(18, 302), Vector2(rect.size.x - 36, 34)), titles[i][0], 27)
		MenuTheme.label(hud, Rect2(rect.position + Vector2(18, 338), Vector2(rect.size.x - 36, 40)), titles[i][1], 29)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(18, 380), Vector2(rect.size.x - 36, 30)),
			race.tr("%.2f KM") % lengths[i],
			22,
			MenuTheme.MUTED
		)
		hud.draw_line(
			rect.position + Vector2(16, rect.size.y - 10),
			rect.end - Vector2(16, 10),
			MenuTheme.AQUA if selected else MenuTheme.YELLOW,
			6,
			true
		)
	MenuTheme.label(hud, Rect2(34, 605, 260, 38), "ALL TRACKS", 26, MenuTheme.INK)
	MenuTheme.label(hud, Rect2(34, 645, 260, 34), "THREE LAPS", 22, MenuTheme.MUTED)
	for item in [
		[hud.COURSE_WEATHER, "WEATHER", race.track_environment.weather.to_upper()],
		[hud.COURSE_PERIOD, "TIME OF DAY", race.track_environment.time_of_day.to_upper()]
	]:
		var rect: Rect2 = item[0]
		MenuTheme.label(
			hud, Rect2(rect.position + Vector2(20, 7), Vector2(rect.size.x - 40, 30)), item[1], 22, MenuTheme.MUTED
		)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(20, 37), Vector2(rect.size.x - 40, 39)),
			race.tr(item[2]) + "  ›",
			29,
			MenuTheme.TEAL
		)


func draw_toggle_switch(row_rect: Rect2, is_on: bool) -> void:
	var switch_rect := Rect2(row_rect.end.x - 110, row_rect.get_center().y - 24, 96, 48)
	var accent := MenuTheme.TEAL if is_on else MenuTheme.BORDER
	hud.glass_box(switch_rect, 24, MenuTheme.AQUA if is_on else MenuTheme.SOFT, accent, 1.8)
	var knob := Vector2(switch_rect.end.x - 24 if is_on else switch_rect.position.x + 24, switch_rect.get_center().y)
	hud.draw_circle(knob + Vector2(0, 2), 20, Color("020a1399"))
	hud.draw_circle(knob, 19, Color("f3fcff") if is_on else Color("c9d4dc"))
	hud.draw_arc(knob, 19, 0, TAU, 32, Color("ffffffdd"), 1.2, true)
	hud.draw_circle(knob + Vector2(-5, -6), 4, Color("ffffffa8"))
	var text_rect := Rect2(switch_rect.position + Vector2(3 if is_on else 47, 0), Vector2(44, 48))
	MenuTheme.label(hud, text_rect, "ON" if is_on else "OFF", 20, MenuTheme.INK, true, 20)


func draw_segmented_selector(row_rect: Rect2, options: Array, current_idx: int) -> void:
	var seg_rect := graphics_segment(0, row_rect).merge(graphics_segment(2, row_rect))
	hud.glass_box(seg_rect, 10, MenuTheme.SOFT, MenuTheme.BORDER, 1.4)
	for i in range(options.size()):
		var sub_rect := graphics_segment(i, row_rect).grow(-3)
		var selected := i == current_idx
		hud.glass_box(
			sub_rect,
			8,
			MenuTheme.AQUA if selected else MenuTheme.PAPER,
			MenuTheme.TEAL if selected else MenuTheme.BORDER,
			2.4 if selected else 1.2
		)
		if selected:
			hud.draw_line(
				sub_rect.position + Vector2(8, 5),
				Vector2(sub_rect.end.x - 8, sub_rect.position.y + 5),
				Color("ffffffb0"),
				2,
				true
			)
		MenuTheme.label(hud, sub_rect.grow(-4), options[i], 24, MenuTheme.INK, true, 22)


func draw_settings() -> void:
	if hud.controls_open:
		preload("res://scripts/ui/touch_layout_panel.gd").draw(hud)
		return
	hud.menu_text.begin()
	PreRaceArt.backdrop(hud)
	hud.modal_begin()
	PreRaceArt.background(hud, "settings", false)
	MenuTheme.label(hud, Rect2(250, 38, 460, 44), "SETTINGS", 36, MenuTheme.INK)
	var version := Rect2(850, 42, 200, 32)
	MenuTheme.label(hud, version.grow(-5), hud.AppVersion.label(), 18, MenuTheme.MUTED, true, 13)

	var rows: Array = [
		[hud.SETTINGS_SOUND, "SOUND", race.sound_enabled],
		[hud.SETTINGS_MUSIC, "MUSIC", race.music_enabled],
		[hud.SETTINGS_MOTION, "REDUCED MOTION", race.motion_reduced],
		[hud.SETTINGS_GRAPHICS, "GRAPHICS", race.graphics_mode],
		[hud.SETTINGS_FPS, "SHOW FPS", race.show_fps],
		[hud.SETTINGS_AUTO, "AUTO GAS", race.auto_accelerate]
	]
	for item in rows:
		var rect: Rect2 = item[0]
		var audio_row: bool = item[1] in ["SOUND", "MUSIC"]
		if audio_row:
			rect = hud.SettingsAudio.toggle_rect(hud, item[1] == "MUSIC")
		var icon := rect.position + Vector2(24, rect.size.y * .5)
		var white := MenuTheme.INK
		match item[1]:
			"SOUND":
				hud.draw_colored_polygon(
					PackedVector2Array(
						[
							icon + Vector2(-11, -6),
							icon + Vector2(-4, -6),
							icon + Vector2(5, -14),
							icon + Vector2(5, 14),
							icon + Vector2(-4, 6),
							icon + Vector2(-11, 6)
						]
					),
					white
				)
				hud.draw_arc(icon + Vector2(3, 0), 14, -.8, .8, 12, white, 2, true)
			"MUSIC":
				hud.draw_line(icon + Vector2(-4, 7), icon + Vector2(-4, -13), white, 3, true)
				hud.draw_line(icon + Vector2(-4, -13), icon + Vector2(10, -16), white, 3, true)
				hud.draw_line(icon + Vector2(10, -16), icon + Vector2(10, 4), white, 3, true)
				hud.draw_circle(icon + Vector2(-8, 8), 6, white)
				hud.draw_circle(icon + Vector2(6, 5), 6, white)
			"REDUCED MOTION":
				for offset in [-8, 0, 8]:
					hud.draw_line(icon + Vector2(-13, offset), icon + Vector2(13, offset), white, 2, true)
					hud.draw_circle(icon + Vector2(-5 if offset == 0 else 5, offset), 3.5, white)
			"GRAPHICS":
				hud.draw_rect(Rect2(icon + Vector2(-14, -12), Vector2(28, 20)), white, false, 2)
				hud.draw_line(icon + Vector2(0, 8), icon + Vector2(0, 14), white, 2, true)
				hud.draw_line(icon + Vector2(-8, 14), icon + Vector2(8, 14), white, 2, true)
			"SHOW FPS":
				hud.draw_arc(icon, 14, PI, TAU, 20, white, 2, true)
				hud.draw_line(icon, icon + Vector2(8, -9), white, 2, true)
				hud.draw_circle(icon, 3, white)
			"AUTO GAS":
				hud.draw_rect(Rect2(icon + Vector2(-10, -13), Vector2(17, 27)), white, false, 2)
				hud.draw_rect(Rect2(icon + Vector2(-6, -9), Vector2(9, 8)), white, false, 1.5)
				hud.draw_polyline(
					PackedVector2Array(
						[icon + Vector2(7, -8), icon + Vector2(13, -2), icon + Vector2(13, 10), icon + Vector2(8, 10)]
					),
					white,
					2,
					true
				)
		var label_start: float = rect.position.x + 44
		var label_end: float = graphics_segment(0).position.x - 12 if item[1] == "GRAPHICS" else rect.end.x - 122
		var label_width: float = maxf(1, label_end - label_start)
		MenuTheme.label(
			hud, Rect2(rect.position + Vector2(44, 0), Vector2(label_width, rect.size.y)), item[1], 23, white, false, 20
		)
		if item[1] == "GRAPHICS":
			draw_segmented_selector(rect, ["AUTO", "HIGH", "FAST"], item[2])
		else:
			draw_toggle_switch(rect, item[2])
			if audio_row:
				hud.SettingsAudio.draw_slider(hud, item[1] == "MUSIC")

	if OS.has_feature("web"):
		PreRaceArt.draw_frame(hud, hud.SETTINGS_FULLSCREEN, "button")
		PreRaceArt.draw_frame(hud, hud.SETTINGS_INSTALL, "button")
		MenuTheme.label(
			hud, hud.SETTINGS_FULLSCREEN.grow(-10), race.shell.fullscreen_label(), 23, MenuTheme.INK, true, 20
		)
		MenuTheme.label(hud, hud.SETTINGS_INSTALL, "INSTALL", 24, MenuTheme.INK, true)
		MenuTheme.label(
			hud,
			Rect2(hud.SETTINGS_MOTION.position.x, 552, hud.SETTINGS_MOTION.size.x, 24),
			hud.install_note,
			18,
			MenuTheme.MUTED,
			true,
			12
		)

	var done_rect: Rect2 = hud.settings_close_rect()
	PreRaceArt.draw_frame(hud, done_rect, "primary")
	MenuTheme.label(hud, hud.settings_controls_rect(), "CONTROLS", 24, MenuTheme.INK, true)
	MenuTheme.label(hud, done_rect, "DONE", 30, MenuTheme.INK, true)

	if hud.pad_on():
		var targets: Array[Rect2] = [
			hud.SETTINGS_SOUND,
			hud.SETTINGS_MUSIC,
			hud.SETTINGS_MOTION,
			hud.SETTINGS_GRAPHICS,
			hud.SETTINGS_FPS,
			hud.SETTINGS_AUTO
		]
		targets.append(hud.settings_controls_rect())
		if OS.has_feature("web"):
			targets.append_array([hud.SETTINGS_FULLSCREEN, hud.SETTINGS_INSTALL])
		targets.append(hud.settings_close_rect())
		hud.draw_rect(targets[clampi(race.settings_focus, 0, targets.size() - 1)].grow(3), MenuTheme.TEAL, false, 3)
	if OS.has_feature("web"):
		if hud.modal_motion.closing:
			race.shell.hide_control()
		else:
			race.shell.sync_control(hud.modal_pose() * hud.SETTINGS_FULLSCREEN)
	hud.modal_end()


# 그리기·입력·읽기 전용 진단이 동일한 세그먼트 좌표를 사용한다.
func graphics_segment(index: int, row_rect: Rect2 = Rect2()) -> Rect2:
	var row: Rect2 = row_rect if row_rect.has_area() else hud.SETTINGS_GRAPHICS
	return Rect2(row.end.x - 446 + clampi(index, 0, 2) * 144, row.get_center().y - 32, 144, 64)


func graphics_index(pos: Vector2) -> int:
	for i in range(3):
		var touch_rect := graphics_segment(i)
		# 행의 8px 상하 완충은 시각 세그먼트를 유지하며 모바일 터치 높이를 확보한다.
		touch_rect.position.y = hud.SETTINGS_GRAPHICS.position.y
		touch_rect.size.y = hud.SETTINGS_GRAPHICS.size.y
		if touch_rect.has_point(pos):
			return i
	return -1


func draw_garage() -> void:
	PreRaceArt.background(hud, "garage")
	PreRaceArt.button(hud, hud.GARAGE_BACK, "‹ BACK")
	MenuTheme.label(hud, Rect2(330, 18, 560, 66), "SELECT CAR", 40)
	MenuTheme.label(hud, Rect2(950, 29, 260, 30), "PERSONAL GHOST", 22, MenuTheme.INK, true)
	MenuTheme.label(hud, Rect2(950, 62, 260, 32), "ON" if race.show_ghost else "OFF", 23, MenuTheme.TEAL, true)
	MenuTheme.label(hud, Rect2(76, 129, 650, 47), race.vehicle.name, 39)
	MenuTheme.label(hud, Rect2(78, 168, 600, 32), race.vehicle["class"], 24, MenuTheme.TEAL)
	if race.previews != null:
		var blend := smoothstep(0, 1, hud.selection_blend)
		if blend < 1:
			MenuTheme.cover(
				hud,
				race.previews.textures[hud.previous_vehicle],
				Rect2(66 - 24 * blend, 194, 690, 270),
				Color(1, 1, 1, 1 - blend)
			)
		MenuTheme.cover(
			hud,
			race.previews.textures[race.selected_vehicle],
			Rect2(66 + 28 * (1 - blend), 194, 690, 270),
			Color(1, 1, 1, blend)
		)
	PreRaceArt.panel(hud, Rect2(800, 122, 400, 346))
	MenuTheme.label(hud, Rect2(824, 135, 350, 30), "PERFORMANCE", 23, MenuTheme.MUTED)
	var abilities := Catalog.abilities(race.selected_vehicle)
	for i in range(4):
		var y := 170 + i * 53.0
		var rating: float = abilities[Catalog.ABILITY_KEYS[i]]
		MenuTheme.label(hud, Rect2(824, y, 260, 32), Catalog.ABILITY_LABELS[i], 25)
		MenuTheme.label(hud, Rect2(1095, y, 78, 32), "%.1f" % rating, 26, MenuTheme.TEAL, true)
		hud.draw_rect(Rect2(824, y + 36, 350, 8), Color("d3e0e5"))
		hud.draw_rect(
			Rect2(824, y + 36, 350 * (hud.shown_abilities[i] if hud.shown_abilities.size() == 4 else rating) / 10.0, 8),
			MenuTheme.AQUA
		)
	MenuTheme.label(hud, Rect2(824, 393, 350, 32), race.vehicle.nitro_title, 25, MenuTheme.TEAL)
	MenuTheme.label(
		hud,
		Rect2(824, 430, 350, 28),
		{"gauge": "DRIFT TO RECHARGE", "charges": "TAP FOR A POWER SHOT", "hybrid": "HOLD OR TAP THE CELL"}[
			race.vehicle.mode
		],
		22,
		MenuTheme.MUTED
	)
	for i in range(Catalog.SPECS.size()):
		var rect: Rect2 = hud.garage_card(i)
		if not rect.has_area():
			continue
		PreRaceArt.panel(hud, rect, "panel", i == race.selected_vehicle)
		if race.previews != null:
			MenuTheme.cover(
				hud, race.previews.textures[i], Rect2(rect.position + Vector2(52, 0), Vector2(rect.size.x - 104, 66))
			)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(12, 64), Vector2(rect.size.x - 24, 28)),
			Catalog.spec(i).name,
			25,
			MenuTheme.INK,
			true
		)
		hud.draw_line(
			rect.position + Vector2(14, rect.size.y - 5),
			rect.end - Vector2(14, 5),
			MenuTheme.AQUA if i == race.selected_vehicle else MenuTheme.YELLOW,
			4,
			true
		)
	PreRaceArt.button(hud, hud.GARAGE_PREVIOUS, "‹", 48)
	PreRaceArt.button(hud, hud.GARAGE_NEXT, "›", 48)
	var note: String = (
		hud.garage_notice
		if hud.garage_notice_left > 0
		else (
			"16 ROUTES / SEPARATE BESTS"
			if race.mode == "tour"
			else race.tr("BEST") + " " + (hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---")
		)
	)
	MenuTheme.label(hud, Rect2(80, 591, 1120, 29), note, 23, MenuTheme.TEAL)
	var plate: int = race.passport.plate_index(race.selected_vehicle)
	for item in [
		[hud.GARAGE_PAINT, "PAINT", garage_paint_label().trim_prefix("PAINT: ")],
		[hud.GARAGE_PLATE, "PLATE", "STANDARD" if plate == 0 else str(race.passport.PLATES[plate])]
	]:
		var rect: Rect2 = item[0]
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(14, 6), Vector2(rect.size.x - 28, 28)),
			item[1],
			22,
			MenuTheme.MUTED,
			true
		)
		MenuTheme.label(
			hud, Rect2(rect.position + Vector2(14, 34), Vector2(rect.size.x - 28, 36)), item[2], 25, MenuTheme.INK, true
		)
	PreRaceArt.button(hud, hud.GARAGE_TUNING, "TUNING", 28)
	PreRaceArt.button(hud, hud.GARAGE_START, "DRIVE  ›", 34)


func garage_paint_label() -> String:
	var data: Dictionary = race.customization.selection(race.selected_vehicle, race.passport)
	if data.paint == Color(race.vehicle.paint).to_html(false):
		return "PAINT: ORIGINAL"
	var reward: Dictionary = race.passport.PAINTS[race.passport.paint_index(race.selected_vehicle)]
	if not str(reward.color).is_empty() and data.paint == Color(reward.color).to_html(false):
		return "PAINT: " + str(reward.name)
	return "PAINT: CUSTOM"
