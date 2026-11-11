extends RefCounted
# 홈·코스 선택·설정·차고 화면을 HUD 캔버스에 그린다. 터치 판정과 주행 화면은 hud.gd가 맡는다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
# 메뉴 화면 전용 배경. 메뉴에서만 읽고 주행이 시작되면 놓아 GPU 메모리를 비운다.
const COURSE_PREVIEWS := [
	"res://assets/ui/course-fuji.png",
	"res://assets/ui/course-speedway.png",
	"res://assets/ui/course-night.tres",
	"res://assets/ui/course-riviera.tres",
	"res://assets/ui/course-gorge.tres"
]
const HOME_BG := "res://assets/ui/home-coast.png"
const GARAGE_BG := "res://assets/ui/garage-bay.png"
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


# 메뉴로 돌아오면 배경을 작업 스레드에서 다시 읽기 시작하고, 주행 중에는 참조를 놓는다.
func sync_menu_art() -> void:
	if race.state in RaceState.DRIVING:
		if menu_art_requested or not menu_art.is_empty():
			menu_art_requested = false
			menu_art.clear()
			# 아직 받아 가지 않은 미리 읽기 결과도 함께 놓는다.
			for path in COURSE_PREVIEWS + [HOME_BG, GARAGE_BG]:
				RenderResources.release(path)
	elif not menu_art_requested:
		menu_art_requested = true
		for path in COURSE_PREVIEWS + [HOME_BG, GARAGE_BG]:
			RenderResources.warm(path)


func draw_home() -> void:
	hud.draw_rect(
		Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()), Color("07111e")
	)
	hud.draw_texture_rect(art(HOME_BG), Rect2(0, 0, 1280, 720), false)
	hud.draw_rect(Rect2(0, 0, 1280, 218), Color("06152b3d"))
	hud.draw_texture_rect(hud.LOGO, Rect2(310, 20, 660, hud.LOGO.get_height() * 660.0 / hud.LOGO.get_width()), false)
	if race.previews != null:
		hud.draw_texture_rect(race.previews.textures[2], Rect2(0, 243, 450, 221), false)
		hud.draw_texture_rect(race.previews.textures[1], Rect2(835, 243, 450, 221), false)
		hud.draw_texture_rect(race.previews.textures[0], Rect2(340, 174, 600, 294), false)
	hud.draw_rect(Rect2(0, 446, 1280, 274), Color("07111ee5"))
	for index in range(2):
		var rect: Rect2 = hud.HOME_TOUR if index == 0 else hud.HOME_TRACK
		var accent: Color = hud.CYAN if index == 0 else Color("ffae72")
		var x := rect.position.x
		hud.slant(rect, Color("112334f5"), 15)
		hud.draw_line(rect.position + Vector2(15, 0), rect.position + Vector2(rect.size.x, 0), accent, 3, true)
		hud.text_at(Vector2(x + 32, rect.position.y + 65), "TOUR" if index == 0 else "TRACK", 54, hud.WHITE)
		hud.text_at(
			Vector2(x + 34, rect.position.y + 108),
			"BRANCHING COAST RUN" if index == 0 else "CHOOSE YOUR CIRCUIT",
			24,
			accent
		)
		hud.text_at(
			Vector2(x + 34, rect.position.y + 144),
			"5 STAGES / 16 ROUTES" if index == 0 else "5 COURSES / 3 LAPS",
			20,
			Color("a5becd")
		)
		hud.text_at(Vector2(x + 450, rect.position.y + 85), ">", 48, accent)
	hud.slant(hud.HOME_SETTINGS, Color("102637ed"), 10)
	hud.centered(Vector2(hud.HOME_SETTINGS.get_center().x, 77), "SETTINGS", 30)
	hud.centered(Vector2(640, 694), hud.AppVersion.label(), 22, Color("b2cbd8"))


func draw_courses() -> void:
	hud.draw_texture_rect(art(GARAGE_BG), Rect2(0, 0, 1280, 720), false)
	hud.slant(hud.GARAGE_BACK, Color("20374a"), 7)
	hud.centered(Vector2(170, 78), "< BACK", 28)
	hud.centered(Vector2(640, 80), "SELECT CIRCUIT", 38)
	var rects := [hud.COURSE_FUJI, hud.COURSE_SPEEDWAY, hud.COURSE_NIGHT, hud.COURSE_RIVIERA, hud.COURSE_GORGE]
	var accents := [hud.CYAN, Color("ffbc72"), Color("c58cff"), Color("ff93ad"), Color("ffad70")]
	var textures := COURSE_PREVIEWS.map(art)
	var titles := [
		["01 / FUJI", "LAKESIDE"],
		["02 / SUNCOAST", "SPEEDWAY"],
		["03 / MIDNIGHT", "HARBOR"],
		["04 / AZURE", "RIVIERA"],
		["05 / SCARLET", "GORGE"]
	]
	var subtitles := [
		"VIADUCT / RIDGE", "INFIELD / BANKED TURNS", "NIGHT / DRIFT GATES", "COAST / HEART DRIFT", "BRIDGE / CANYON ADS"
	]
	var lengths := ["5.72 KM / 3 LAPS", "5.76 KM / 3 LAPS", "2.74 KM / 3 LAPS", "3.64 KM / 3 LAPS", "3.54 KM / 3 LAPS"]
	for i in range(5):
		var rect: Rect2 = rects[i]
		var accent: Color = accents[i]
		hud.slant(rect, Color("142738"), 10)
		var texture: Texture2D = textures[i]
		var image_box := Rect2(rect.position + Vector2(12, 12), Vector2(rect.size.x - 24, 224))
		# Cover crop only; original generated assets remain intact.
		var source := Rect2(Vector2.ZERO, texture.get_size())
		var ratio := image_box.size.x / image_box.size.y
		if source.size.x / source.size.y > ratio:
			var width := source.size.y * ratio
			source.position.x = (source.size.x - width) * 0.5
			source.size.x = width
		else:
			var height := source.size.x / ratio
			source.position.y = (source.size.y - height) * 0.5
			source.size.y = height
		hud.draw_texture_rect_region(texture, image_box, source)
		var x := rect.position.x + 22
		hud.text_at(Vector2(x, 420), titles[i][0], 21, accent)
		hud.text_at(Vector2(x, 448), titles[i][1], 21, accent)
		hud.text_at(Vector2(x, 480), subtitles[i], 13, hud.WHITE)
		hud.text_at(Vector2(x, 507), lengths[i], 14, Color("adc2d0"))
	hud.centered(Vector2(640, 675), "THREE LAPS / TRACK02: 16 RACERS / OTHERS: 8", 18, Color("8299a7"))


func draw_settings() -> void:
	hud.draw_rect(Rect2(0, 0, 1280, 720), Color("020812d9"))
	hud.slant(Rect2(300, 40, 680, 640), Color("101e2bfc"), 20)
	hud.text_at(Vector2(365, 78), "SETTINGS", 36)
	hud.centered(Vector2(800, 76), hud.AppVersion.label(), 22, Color("b2cbd8"))
	for rect in [
		hud.SETTINGS_SOUND,
		hud.SETTINGS_MOTION,
		hud.SETTINGS_GRAPHICS,
		hud.SETTINGS_FPS,
		hud.SETTINGS_AUTO,
		hud.SETTINGS_FULLSCREEN,
		hud.SETTINGS_INSTALL
	]:
		hud.slant(rect, Color("20374a"), 9)
	hud.text_at(hud.SETTINGS_SOUND.position + Vector2(28, 49), "SOUND", 28)
	hud.text_at(hud.SETTINGS_SOUND.position + Vector2(450, 49), "ON" if race.sound_enabled else "OFF", 30, hud.CYAN)
	hud.text_at(hud.SETTINGS_MOTION.position + Vector2(28, 49), "REDUCED MOTION", 26)
	hud.text_at(hud.SETTINGS_MOTION.position + Vector2(450, 49), "ON" if race.motion_reduced else "OFF", 30, hud.CYAN)
	hud.text_at(hud.SETTINGS_GRAPHICS.position + Vector2(28, 49), "GRAPHICS", 28)
	hud.text_at(
		hud.SETTINGS_GRAPHICS.position + Vector2(430, 49), ["AUTO", "HIGH", "FAST"][race.graphics_mode], 28, hud.CYAN
	)
	hud.text_at(hud.SETTINGS_FPS.position + Vector2(18, 49), "SHOW FPS", 22)
	hud.text_at(hud.SETTINGS_FPS.position + Vector2(190, 49), "ON" if race.show_fps else "OFF", 25, hud.CYAN)
	hud.text_at(hud.SETTINGS_AUTO.position + Vector2(18, 49), "AUTO GAS", 22)
	hud.text_at(hud.SETTINGS_AUTO.position + Vector2(190, 49), "ON" if race.auto_accelerate else "OFF", 25, hud.CYAN)
	var fullscreen_label: String = (
		race.shell.fullscreen_label() if race.has_method("fullscreen_label") else "ENTER FULLSCREEN"
	)
	hud.text_at(hud.SETTINGS_FULLSCREEN.position + Vector2(28, 49), fullscreen_label, 28)
	hud.text_at(hud.SETTINGS_FULLSCREEN.position + Vector2(489, 49), ">", 32, hud.CYAN)
	hud.text_at(hud.SETTINGS_INSTALL.position + Vector2(28, 49), "INSTALL GAME", 30, hud.WHITE)
	hud.text_at(hud.SETTINGS_INSTALL.position + Vector2(489, 49), "+", 35, hud.CYAN)
	if not hud.install_note.is_empty():
		hud.centered(Vector2(640, 585), hud.install_note, 16, Color("b2cbd8"))
	hud.slant(hud.SETTINGS_CLOSE, hud.CYAN, 10)
	hud.centered(Vector2(640, hud.SETTINGS_CLOSE.position.y + 51), "DONE", 34, Color("0a1b2b"))
	if hud.pad_on():
		var rows: Array[Rect2] = [
			hud.SETTINGS_SOUND,
			hud.SETTINGS_MOTION,
			hud.SETTINGS_GRAPHICS,
			hud.SETTINGS_FPS,
			hud.SETTINGS_AUTO,
			hud.SETTINGS_FULLSCREEN,
			hud.SETTINGS_INSTALL,
			hud.SETTINGS_CLOSE
		]
		hud.draw_rect(rows[clampi(race.settings_focus, 0, rows.size() - 1)].grow(4), hud.GOLD, false, 4.0)
	if race.has_method("sync_fullscreen_button"):
		race.shell.sync_control(hud.SETTINGS_FULLSCREEN)


func draw_garage() -> void:
	var color := Color(race.vehicle.accent)
	hud.draw_texture_rect(art(GARAGE_BG), Rect2(0, 0, 1280, 720), false)
	hud.draw_line(Vector2(60, 120), Vector2(1220, 120), Color("264152"), 1, true)
	hud.slant(hud.GARAGE_BACK, Color("20374a"), 10)
	hud.centered(Vector2(hud.GARAGE_BACK.get_center().x, 78), "< BACK", 28, hud.WHITE)
	hud.centered(Vector2(640, 68), ("TRACK" if race.mode == "track" else "TOUR") + " / GARAGE", 22, Color("9db6c9"))
	hud.text_at(Vector2(1105, 68), "%d / %d" % [race.selected_vehicle + 1, Catalog.SPECS.size()], 16, color)
	hud.slant(Rect2(92, 129, 675, 76), Color("07111ebd"), 10)
	hud.text_at(Vector2(120, 168), race.vehicle.name, 48)
	hud.text_at(Vector2(123, 195), race.vehicle["class"], 21, color)
	if race.previews != null:
		var blend := smoothstep(0, 1, hud.selection_blend)
		if blend < 1:
			hud.draw_texture_rect(
				race.previews.textures[hud.previous_vehicle],
				Rect2(80 - 24 * blend, 210, 690, 300),
				false,
				Color(1, 1, 1, 1 - blend)
			)
		hud.draw_texture_rect(
			race.previews.textures[race.selected_vehicle],
			Rect2(80 + 28 * (1 - blend), 210, 690, 300),
			false,
			Color(1, 1, 1, blend)
		)
	hud.slant(Rect2(800, 130, 395, 380), Color("07111eac"), 10)
	hud.text_at(Vector2(826, 162), "PERFORMANCE", 20, Color("9db6c9"))
	var abilities := Catalog.abilities(race.selected_vehicle)
	for i in range(4):
		var y := 203.0 + i * 58
		var rating: float = abilities[Catalog.ABILITY_KEYS[i]]
		hud.text_at(Vector2(826, y), Catalog.ABILITY_LABELS[i], 26, Color("c8d9e4"))
		hud.text_at(Vector2(1115, y), "%.1f" % rating, 26, color)
		hud.draw_rect(Rect2(826, y + 13, 334, 5), Color("263746"))
		hud.draw_rect(
			Rect2(826, y + 13, 334 * (hud.shown_abilities[i] if hud.shown_abilities.size() == 4 else rating) / 10.0, 5),
			color
		)
	hud.text_at(Vector2(826, 455), race.vehicle.nitro_title, 24, color)
	hud.text_at(Vector2(826, 483), race.vehicle.nitro_help, 19, Color("a1b8c9"))
	hud.draw_rect(Rect2(80, 486, 690, 34), Color("07111ebd"))
	hud.text_at(Vector2(80, 511), race.vehicle.tagline, 22, Color("9db6c9"))
	for i in range(Catalog.SPECS.size()):
		var rect: Rect2 = hud.garage_card(i)
		var v := Catalog.spec(i)
		var selected: bool = i == race.selected_vehicle
		hud.slant(rect, Color("203345") if selected else Color("101d2b"), 8)
		if selected:
			hud.draw_line(rect.position + Vector2(8, rect.size.y), rect.end, Color(v.accent), 3, true)
		hud.text_at(rect.position + Vector2(22, 35), v.name, 28, Color(v.accent) if selected else Color("bdcedb"))
		var role: String = v.role
		hud.text_at(rect.position + Vector2(23, 66), role, 20, Color("94acbe"))
	hud.text_at(
		Vector2(80, 678),
		"BEST " + (hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---"),
		22,
		hud.GOLD
	)
	hud.slant(hud.GARAGE_START, color, 8)
	hud.centered(Vector2(hud.GARAGE_START.get_center().x, 680), "DRIVE", 34, Color("07111e"))
