extends RefCounted
# 밝은 해안 메뉴를 그린다. 입력 판정은hud.gd의 같은 사각형을 사용한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const COURSE_PREVIEWS := [
	"res://assets/ui/courses/fuji.tres",
	"res://assets/ui/courses/speedway.tres",
	"res://assets/ui/courses/night.tres",
	"res://assets/ui/courses/riviera.tres",
	"res://assets/ui/courses/gorge.tres"
]
const TOUR_PREVIEW := "res://assets/ui/courses/tour.tres"
const HOME_BG := "res://assets/ui/backgrounds/home_coast.png"
const GARAGE_BG := "res://assets/ui/backgrounds/tuning_bay.png"
const COUNTDOWN_ART := "res://assets/ui/controls/countdown_ring.png"
var countdown_art: Texture2D
var menu_art: Dictionary = {}
var menu_art_requested := false
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


func countdown_texture() -> Texture2D:
	if countdown_art == null:
		countdown_art = RenderResources.fetch(COUNTDOWN_ART)
	return countdown_art


func sync_menu_art() -> void:
	# 카운트다운은 주행 상태이므로 메뉴 이미지 해제 큐와 수명을 분리한다.
	if race.state != RaceState.COUNTDOWN and countdown_art != null:
		countdown_art = null
		RenderResources.release(COUNTDOWN_ART)
	if race.state in RaceState.DRIVING:
		if menu_art_requested or not menu_art.is_empty():
			menu_art_requested = false
			menu_art.clear()
			for path in (
				COURSE_PREVIEWS + [HOME_BG, GARAGE_BG, TOUR_PREVIEW, MenuTheme.HEADER_ART, MenuTheme.PRIMARY_ART]
			):
				RenderResources.release(path)
	elif not menu_art_requested:
		menu_art_requested = true
		for path in COURSE_PREVIEWS + [HOME_BG, GARAGE_BG, TOUR_PREVIEW, MenuTheme.HEADER_ART, MenuTheme.PRIMARY_ART]:
			RenderResources.warm(path)


func draw_home() -> void:
	MenuTheme.canvas(hud)
	MenuTheme.cover(hud, art(HOME_BG), Rect2(32, 118, 1216, 330))
	hud.draw_rect(Rect2(32, 118, 1216, 330), Color(1, 1, 1, .12))
	MenuTheme.label(hud, Rect2(320, 12, 600, 82), "INITIAL SJ", 64, MenuTheme.INK, true)
	if race.previews != null:
		hud.draw_texture_rect(race.previews.textures[2], Rect2(40, 230, 410, 201), false)
		hud.draw_texture_rect(race.previews.textures[1], Rect2(830, 230, 410, 201), false)
		hud.draw_texture_rect(race.previews.textures[0], Rect2(350, 170, 580, 284), false)
	for index in range(2):
		var rect: Rect2 = hud.HOME_TOUR if index == 0 else hud.HOME_TRACK
		MenuTheme.panel(hud, rect, MenuTheme.PAPER)
		MenuTheme.cover(
			hud,
			art(TOUR_PREVIEW if index == 0 else COURSE_PREVIEWS[1]),
			Rect2(rect.end.x - 164, rect.position.y + 12, 148, rect.size.y - 24)
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
	MenuTheme.panel(hud, hud.HOME_PASSPORT, MenuTheme.SOFT)
	MenuTheme.label(hud, Rect2(45, 32, 230, 36), "TOUR PASSPORT", 24, MenuTheme.INK, true)
	MenuTheme.label(
		hud, Rect2(45, 69, 230, 28), race.tr("%d / 5 GOALS") % race.passport.goals.size(), 22, MenuTheme.TEAL, true
	)
	MenuTheme.button(hud, hud.HOME_SETTINGS, "SETTINGS", MenuTheme.SOFT, 30)
	MenuTheme.label(hud, Rect2(440, 668, 400, 38), hud.AppVersion.label(), 22, MenuTheme.MUTED, true)


func draw_courses() -> void:
	MenuTheme.canvas(hud)
	MenuTheme.button(hud, hud.GARAGE_BACK, "‹ BACK")
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
		MenuTheme.panel(hud, rect, MenuTheme.PAPER, selected)
		MenuTheme.cover(
			hud, art(COURSE_PREVIEWS[i]), Rect2(rect.position + Vector2(8, 8), Vector2(rect.size.x - 16, 286))
		)
		var badge := Rect2(rect.position + Vector2(16, 16), Vector2(52, 46))
		MenuTheme.panel(hud, badge, MenuTheme.YELLOW, false, 5)
		MenuTheme.label(hud, badge, "%02d" % (i + 1), 26, MenuTheme.INK, true)
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
		MenuTheme.panel(hud, rect, MenuTheme.SOFT)
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
	var switch_w := 72.0
	var switch_h := 36.0
	var switch_rect := Rect2(
		row_rect.end.x - switch_w - 14.0, row_rect.position.y + (row_rect.size.y - switch_h) * 0.5, switch_w, switch_h
	)
	if is_on:
		hud.glass_box(switch_rect, 18.0, Color("00e5ff33"), Color("00e5ff"), 2.0)
		# 네온 트랙 내부 글로우
		hud.draw_rect(switch_rect.grow(-3), Color("00e5ff22"))
		var knob_pos := Vector2(switch_rect.end.x - 18.0, switch_rect.position.y + 18.0)
		hud.draw_circle(knob_pos, 16.0, Color("00e5ff44"))
		hud.draw_circle(knob_pos, 12.0, Color.WHITE)
		hud.draw_circle(knob_pos, 5.0, Color("00e5ff"))
		MenuTheme.label(
			hud,
			Rect2(switch_rect.position.x + 8.0, switch_rect.position.y + 8.0, 26.0, 20.0),
			"ON",
			13,
			Color("00e5ff"),
			true,
			10
		)
	else:
		hud.glass_box(switch_rect, 18.0, Color("0a1420"), Color("22364f"), 1.2)
		var knob_pos := Vector2(switch_rect.position.x + 18.0, switch_rect.position.y + 18.0)
		hud.draw_circle(knob_pos, 12.0, Color("455a64"))
		hud.draw_circle(knob_pos, 5.0, Color("263238"))
		MenuTheme.label(
			hud,
			Rect2(switch_rect.end.x - 34.0, switch_rect.position.y + 8.0, 26.0, 20.0),
			"OFF",
			13,
			Color("546e7a"),
			true,
			10
		)


func draw_segmented_selector(row_rect: Rect2, options: Array, current_idx: int) -> void:
	var total_w := 288.0
	var total_h := 64.0
	var seg_rect := Rect2(
		row_rect.end.x - total_w - 14.0, row_rect.position.y + (row_rect.size.y - total_h) * 0.5, total_w, total_h
	)
	hud.glass_box(seg_rect, 10.0, Color("081322"), Color("1a2a40"), 1.2)
	var seg_w: float = total_w / float(options.size())
	for i in range(options.size()):
		var sub_rect := Rect2(seg_rect.position.x + i * seg_w, seg_rect.position.y, seg_w, total_h)
		var is_active: bool = i == current_idx
		if is_active:
			hud.glass_box(sub_rect, 8.0, Color("00e5ff38"), Color("00e5ff"), 1.8)
			# 액티브 인디케이터 하단 바
			hud.draw_line(
				Vector2(sub_rect.position.x + 6, sub_rect.end.y - 2),
				Vector2(sub_rect.end.x - 6, sub_rect.end.y - 2),
				Color("00e5ff"),
				2.5
			)
			MenuTheme.label(hud, sub_rect, options[i], 16, Color("00e5ff"), true, 12)
		else:
			MenuTheme.label(hud, sub_rect, options[i], 14, Color("607d8b"), true, 10)


func draw_settings() -> void:
	if hud.controls_open:
		preload("res://scripts/ui/touch_layout_panel.gd").draw(hud)
		return
	# 배경 홈 화면의 글자를 모달 위에 겹쳐 그리지 않는다.
	hud.menu_text.begin()
	hud.draw_rect(Rect2(0, 0, 1280, 720), Color("030812b8"))
	hud.modal_begin()
	var modal_rect := Rect2(290, 24, 700, 672)
	hud.glass_box(modal_rect, 20.0, Color("081220f4"), Color("00e5ff66"), 1.8)

	# 상단 포인트 네온 하이라이트 라인
	hud.draw_line(
		Vector2(modal_rect.position.x + 36, modal_rect.position.y + 3),
		Vector2(modal_rect.end.x - 36, modal_rect.position.y + 3),
		Color("00e5ffcc"),
		2.0
	)

	MenuTheme.label(hud, Rect2(335, 38, 280, 44), "SETTINGS", 34, Color.WHITE)
	var ver_capsule := Rect2(740, 42, 200, 32)
	hud.glass_box(ver_capsule, 12.0, Color("00e5ff18"), Color("00e5ff55"), 1.0)
	MenuTheme.label(hud, ver_capsule, hud.AppVersion.label(), 16, Color("00e5ff"), true, 12)

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
		hud.glass_box(rect, 10.0, Color("0b182bcd"), Color("00e5ff26"), 1.0)
		MenuTheme.label(
			hud,
			Rect2(
				rect.position + Vector2(18, 0),
				Vector2(rect.size.x - (320 if item[1] == "GRAPHICS" else 118), rect.size.y)
			),
			item[1],
			21,
			Color("eceff1")
		)
		if item[1] == "GRAPHICS":
			draw_segmented_selector(rect, ["AUTO", "HIGH", "FAST"], item[2])
		else:
			draw_toggle_switch(rect, item[2])

	if OS.has_feature("web"):
		hud.glass_box(hud.SETTINGS_FULLSCREEN, 12.0, Color("00e5ff20"), Color("00e5ff88"), 1.5)
		MenuTheme.label(hud, hud.SETTINGS_FULLSCREEN, race.shell.fullscreen_label(), 22, Color("00e5ff"), true)
		hud.glass_box(hud.SETTINGS_INSTALL, 12.0, Color("0d1d33c8"), Color("19dcff44"), 1.2)
		MenuTheme.label(hud, hud.SETTINGS_INSTALL, "INSTALL", 22, Color("00e5ff"), true)
		MenuTheme.label(hud, Rect2(350, 552, 580, 24), hud.install_note, 18, Color("8caec0"), true, 12)

	var done_rect: Rect2 = hud.settings_close_rect()
	hud.glass_box(hud.settings_controls_rect(), 12, Color("12374b"), Color("00e5ff"), 1.5)
	MenuTheme.label(hud, hud.settings_controls_rect(), "CONTROLS", 24, Color("00e5ff"), true)
	hud.glass_box(done_rect, 14.0, Color("00e5ff33"), Color("00e5ff"), 2.0)
	MenuTheme.label(hud, done_rect, "DONE", 30, Color("00e5ff"), true)

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
		hud.draw_rect(targets[clampi(race.settings_focus, 0, targets.size() - 1)].grow(3), Color("00e5ff"), false, 3)

	if OS.has_feature("web"):
		if hud.modal_motion.closing:
			race.shell.hide_control()
		else:
			race.shell.sync_control(hud.modal_pose() * hud.SETTINGS_FULLSCREEN)
	hud.modal_end()


func graphics_index(pos: Vector2) -> int:
	var left: float = hud.SETTINGS_GRAPHICS.end.x - 302
	return clampi(int((pos.x - left) / 96), 0, 2) if pos.x >= left else -1


func draw_garage() -> void:
	MenuTheme.canvas(hud)
	MenuTheme.button(hud, hud.GARAGE_BACK, "‹ BACK")
	MenuTheme.label(hud, Rect2(330, 18, 560, 66), "SELECT CAR", 40)
	MenuTheme.panel(hud, hud.GARAGE_GHOST, MenuTheme.SOFT)
	MenuTheme.label(hud, Rect2(950, 29, 260, 30), "PERSONAL GHOST", 22, MenuTheme.INK, true)
	MenuTheme.label(hud, Rect2(950, 62, 260, 32), "ON" if race.show_ghost else "OFF", 23, MenuTheme.TEAL, true)
	MenuTheme.cover(hud, art(GARAGE_BG), Rect2(48, 122, 735, 346))
	hud.draw_rect(Rect2(48, 122, 735, 346), Color(1, 1, 1, .6))
	hud.draw_rect(Rect2(48, 122, 735, 88), Color(1, 1, 1, .9))
	MenuTheme.label(hud, Rect2(76, 129, 650, 47), race.vehicle.name, 39)
	MenuTheme.label(hud, Rect2(78, 176, 600, 34), race.vehicle["class"], 24, MenuTheme.TEAL)
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
	MenuTheme.panel(hud, Rect2(800, 122, 400, 346), MenuTheme.PAPER, true)
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
		MenuTheme.panel(hud, rect, MenuTheme.PAPER, i == race.selected_vehicle)
		if race.previews != null:
			MenuTheme.cover(
				hud, race.previews.textures[i], Rect2(rect.position + Vector2(52, 0), Vector2(rect.size.x - 104, 74))
			)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(12, 72), Vector2(rect.size.x - 24, 30)),
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
	MenuTheme.button(hud, hud.GARAGE_PREVIOUS, "‹", MenuTheme.SOFT, 48)
	MenuTheme.button(hud, hud.GARAGE_NEXT, "›", MenuTheme.SOFT, 48)
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
		MenuTheme.panel(hud, rect, MenuTheme.SOFT)
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
	MenuTheme.button(hud, hud.GARAGE_TUNING, "TUNING", MenuTheme.SOFT, 28)
	MenuTheme.button(hud, hud.GARAGE_START, "DRIVE  ›", MenuTheme.YELLOW, 34)


func garage_paint_label() -> String:
	var data: Dictionary = race.customization.selection(race.selected_vehicle, race.passport)
	if data.paint == Color(race.vehicle.paint).to_html(false):
		return "PAINT: ORIGINAL"
	var reward: Dictionary = race.passport.PAINTS[race.passport.paint_index(race.selected_vehicle)]
	if not str(reward.color).is_empty() and data.paint == Color(reward.color).to_html(false):
		return "PAINT: " + str(reward.name)
	return "PAINT: CUSTOM"
