extends Control
# 코스 준비는 메인 스레드에서 수행하므로 시작 전에 화면을 그리고 준비 단계 사이에 갱신한다.
const AppVersion = preload("res://scripts/platform/app_version.gd")
const BACKGROUND_PATH := "res://assets/ui/rev3/backgrounds/clean_start.png"
const Pool = preload("res://scripts/rendering/render_resources.gd")
var background_art: Texture2D
var surround_art: Texture2D
const SURROUND_PATH := "res://assets/ui/rev3/backgrounds/clean_start.png"
const FONT = preload("res://assets/ui/rev3/fonts/interface_font.tres")
const Art = preload("res://scripts/ui/rev3_art.gd")
var art := Art.new()
const MenuLayout = preload("res://scripts/ui/menu_layout.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const CYAN := MenuTheme.AQUA
const INK := MenuTheme.INK
const STEP_LABELS := ["PREPARING THE TRACK", "BUILDING THE WORLD", "WARMING UP THE ENGINE", "READY"]
const LOADING_TIPS := [
	"DRIFT THROUGH CORNERS TO FILL THE NITRO BAR",
	"TAP THE GUARDRAIL AND YOU LOSE SPEED - STAY ON THE ROAD",
	"NARROW STRETCHES REWARD EARLY BRAKING",
	"SLIPSTREAM THE CAR AHEAD FOR A FREE BOOST",
	"PLUG IN A GAMEPAD FOR ANALOG STEERING"
]
var loading_title := ""
var load_progress := 0.0
var step_index := 0
var tip_index := 0
var started_at_msec := 0
var show_illustration := false
var spinner_angle_rad := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func begin(value: String, long_load: bool = false) -> void:
	started_at_msec = Time.get_ticks_msec()
	background_art = Pool.fetch(BACKGROUND_PATH) if long_load else null
	surround_art = Pool.fetch(SURROUND_PATH) if long_load else null
	show_illustration = long_load
	loading_title = value
	load_progress = 0.08
	step_index = 0
	tip_index = int(Time.get_ticks_msec() / 1000) % LOADING_TIPS.size()
	visible = true
	queue_redraw()


func advance(to_step: int, to_progress: float) -> void:
	step_index = clampi(to_step, 0, STEP_LABELS.size() - 1)
	load_progress = clampf(to_progress, 0, 1)
	queue_redraw()


func finish() -> void:
	visible = false
	background_art = null
	surround_art = null
	Pool.release(BACKGROUND_PATH)
	Pool.release(SURROUND_PATH)
	art.release()


func _process(delta: float) -> void:
	if not visible:
		return
	spinner_angle_rad += delta * 4
	if not show_illustration and Time.get_ticks_msec() - started_at_msec >= 650:
		background_art = Pool.fetch(BACKGROUND_PATH)
		surround_art = Pool.fetch(SURROUND_PATH)
		show_illustration = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Art.BLUE)
	var safe := MenuLayout.safe_rect(size)
	var scale_factor := MenuLayout.scale_for(safe)
	var origin := MenuLayout.origin_for(safe)
	draw_set_transform(origin, 0, Vector2.ONE * scale_factor)
	var bounds := Rect2(-origin / scale_factor, size / scale_factor)
	if show_illustration:
		art.background(self, "loading_long", bounds)
		art.draw_part(self, "loading_long", "brand_header", art.rect("loading_long", "brand_header", bounds))
		_centered(Vector2(278, bounds.position.y + 103), "INITIAL SJ", 54, Art.WHITE, FONT)
		var footer := Rect2(bounds.position.x, bounds.end.y - 126, bounds.size.x, 126)
		Art.draw_panel(self, footer, false, 0)
		_centered(Vector2(640, footer.position.y + 36), loading_title, 26, Art.WHITE, FONT)
	else:
		art.background(self, "loading_short", bounds)
		draw_arc(Vector2(640, 298), 30, spinner_angle_rad, spinner_angle_rad + TAU * .72, 40, Art.GOLD, 5, true)
		_centered(Vector2(640, 374), loading_title, 28, Art.WHITE, FONT)
	var bar := Rect2(300, bounds.end.y - 69 if show_illustration else 409, 680, 10)
	draw_rect(bar, Art.WHITE.darkened(.4))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * load_progress, bar.size.y)), Art.GOLD)
	_centered(Vector2(640, bar.end.y + 29), STEP_LABELS[step_index], 22, Art.WHITE, FONT)
	_centered(Vector2(1150, bounds.end.y - 10), AppVersion.label(), 17, Art.WHITE, FONT)


func _exit_tree() -> void:
	art.release()


func _centered(pos: Vector2, value: String, size_px: int, color: Color, face: Font) -> void:
	value = tr(value)
	var available := minf(pos.x, 1280 - pos.x) * 2 - 40
	while size_px > 22 and face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > available:
		size_px -= 1
	if face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > available:
		while (
			not value.is_empty()
			and face.get_string_size(value + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > available
		):
			value = value.left(value.length() - 1)
		value += "…"
	var width := face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(face, pos - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
