extends Control
# 코스 준비는 메인 스레드에서 수행하므로 시작 전에 화면을 그리고 준비 단계 사이에 갱신한다.
const AppVersion = preload("res://scripts/platform/app_version.gd")
const GAME_LOGO = preload("res://assets/ui/branding/initialsj_logo.svg")
const BACKGROUND_ART = preload("res://assets/ui/backgrounds/loading_coast.png")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
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
var spinner_angle := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func begin(value: String, long_load: bool = false) -> void:
	started_at_msec = Time.get_ticks_msec()
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


func _process(delta: float) -> void:
	if not visible:
		return
	spinner_angle += delta * 4
	if Time.get_ticks_msec() - started_at_msec >= 650:
		show_illustration = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("e8f7fc"))
	if show_illustration:
		var factor := maxf(size.x / BACKGROUND_ART.get_width(), size.y / BACKGROUND_ART.get_height())
		var art_size := BACKGROUND_ART.get_size() * factor
		draw_texture_rect(BACKGROUND_ART, Rect2((size - art_size) * .5, art_size), false)
	var safe := MenuLayout.safe_rect(size)
	var scale_factor := MenuLayout.scale_for(safe)
	var origin := MenuLayout.origin_for(safe)
	draw_set_transform(origin, 0, Vector2.ONE * scale_factor)
	if show_illustration:
		draw_rect(Rect2(0, 540, 1280, 180), Color(.97, 1, 1, .93))
		draw_line(Vector2(0, 540), Vector2(1280, 540), Color("20cbd0"), 3)
		draw_texture_rect(GAME_LOGO, Rect2(720, 85, 480, GAME_LOGO.get_height() * 480.0 / GAME_LOGO.get_width()), false)
	else:
		draw_arc(Vector2(640, 285), 26, spinner_angle, spinner_angle + TAU * .72, 40, CYAN, 4, true)
	if loading_title != "":
		_centered(Vector2(640, 581 if show_illustration else 356), loading_title, 30, INK, FONT)
	var bar := Rect2(Vector2(300, 602 if show_illustration else 386), Vector2(680, 10))
	draw_rect(bar, Color("c9e3eb"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * load_progress, bar.size.y)), Color("17b8c7"))
	draw_rect(
		Rect2(bar.position + Vector2(bar.size.x * load_progress - 26, 0), Vector2(26, bar.size.y)).intersection(bar),
		Color("ffdf45")
	)
	_centered(Vector2(640, 644 if show_illustration else 430), STEP_LABELS[step_index], 24, Color("187f97"), FONT)
	if show_illustration:
		_centered(Vector2(640, 681), LOADING_TIPS[tip_index], 22, Color("536e83"), FONT)
	_centered(Vector2(1140, 706), AppVersion.label(), 22, Color("536e83"), FONT)


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
