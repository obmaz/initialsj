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


func draw_settings() -> void:
	# 배경 홈 화면의 글자를 모달 위에 겹쳐 그리지 않는다.
	hud.menu_text.begin()
	hud.draw_rect(Rect2(0, 0, 1280, 720), Color(.85, .95, .97, .94))
	MenuTheme.panel(hud, Rect2(300, 28, 680, 664 if OS.has_feature("web") else 584), MenuTheme.PAPER)
	MenuTheme.label(hud, Rect2(365, 40, 300, 48), "SETTINGS", 36)
	MenuTheme.label(hud, Rect2(730, 46, 185, 40), hud.AppVersion.label(), 22, MenuTheme.MUTED, true)
	var rows: Array = [
		[hud.SETTINGS_SOUND, "SOUND", "ON" if race.sound_enabled else "OFF"],
		[hud.SETTINGS_MUSIC, "MUSIC", "ON" if race.music_enabled else "OFF"],
		[hud.SETTINGS_MOTION, "REDUCED MOTION", "ON" if race.motion_reduced else "OFF"],
		[hud.SETTINGS_GRAPHICS, "GRAPHICS", ["AUTO", "HIGH", "FAST"][race.graphics_mode]],
		[hud.SETTINGS_FPS, "SHOW FPS", "ON" if race.show_fps else "OFF"],
		[hud.SETTINGS_AUTO, "AUTO GAS", "ON" if race.auto_accelerate else "OFF"]
	]
	for item in rows:
		var rect: Rect2 = item[0]
		MenuTheme.panel(hud, rect, MenuTheme.SOFT)
		var value_width := 76.0 if rect.size.x < 300 else 116.0
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(16, 0), Vector2(rect.size.x - value_width - 28, rect.size.y)),
			item[1],
			26
		)
		MenuTheme.label(
			hud,
			Rect2(rect.end.x - value_width - 10, rect.position.y, value_width, rect.size.y),
			item[2],
			28,
			MenuTheme.TEAL,
			true
		)
	if OS.has_feature("web"):
		MenuTheme.button(hud, hud.SETTINGS_FULLSCREEN, race.shell.fullscreen_label(), MenuTheme.SOFT, 28)
		MenuTheme.button(hud, hud.SETTINGS_INSTALL, "INSTALL", MenuTheme.SOFT, 28)
		MenuTheme.label(hud, Rect2(350, 552, 580, 24), hud.install_note, 22, MenuTheme.MUTED, true)
	MenuTheme.button(hud, hud.settings_close_rect(), "DONE", MenuTheme.YELLOW, 30)
	if hud.pad_on():
		var targets: Array[Rect2] = [
			hud.SETTINGS_SOUND,
			hud.SETTINGS_MUSIC,
			hud.SETTINGS_MOTION,
			hud.SETTINGS_GRAPHICS,
			hud.SETTINGS_FPS,
			hud.SETTINGS_AUTO
		]
		if OS.has_feature("web"):
			targets.append_array([hud.SETTINGS_FULLSCREEN, hud.SETTINGS_INSTALL])
		targets.append(hud.settings_close_rect())
		hud.draw_rect(targets[clampi(race.settings_focus, 0, targets.size() - 1)].grow(3), MenuTheme.TEAL, false, 3)
	if OS.has_feature("web"):
		race.shell.sync_control(hud.SETTINGS_FULLSCREEN)


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
