extends Control
# Loading screen drawn over the transition cover while a course is being built. The build runs
# on the main thread, so the card is drawn once before it starts and updated between steps.
const AppVersion = preload("res://scripts/platform/app_version.gd")
const LOGO = preload("res://assets/ui/initialsj-logo.svg")
const ART = preload("res://assets/ui/drive-loading.png")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
const CYAN := Color("19dcff")
const WHITE := Color("f6f7fa")
const STEPS := ["PREPARING THE TRACK", "BUILDING THE WORLD", "WARMING UP THE ENGINE", "READY"]
const TIPS := [
	"DRIFT THROUGH CORNERS TO FILL THE NITRO BAR",
	"TAP THE GUARDRAIL AND YOU LOSE SPEED - STAY ON THE ROAD",
	"NARROW STRETCHES REWARD EARLY BRAKING",
	"SLIPSTREAM THE CAR AHEAD FOR A FREE BOOST",
	"PLUG IN A GAMEPAD FOR ANALOG STEERING"
]
var title := ""
var progress := 0.0
var step := 0
var tip := 0
var started_at := 0
var illustrated := false
var spin := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func begin(value: String, long_load: bool = false) -> void:
	started_at = Time.get_ticks_msec()
	illustrated = long_load
	title = value
	progress = 0.08
	step = 0
	tip = int(Time.get_ticks_msec() / 1000) % TIPS.size()
	visible = true
	queue_redraw()


func advance(to_step: int, to_progress: float) -> void:
	step = clampi(to_step, 0, STEPS.size() - 1)
	progress = clampf(to_progress, 0, 1)
	queue_redraw()


func finish() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	spin += delta * 4
	if Time.get_ticks_msec() - started_at >= 650:
		illustrated = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07111e"))
	if illustrated:
		var factor := maxf(size.x / ART.get_width(), size.y / ART.get_height())
		var art_size := ART.get_size() * factor
		draw_texture_rect(ART, Rect2((size - art_size) * .5, art_size), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, .02, .05, .35))
	var scale_factor := minf(size.x / 1280.0, size.y / 720.0)
	var origin := (size - Vector2(1280, 720) * scale_factor) * 0.5
	draw_set_transform(origin, 0, Vector2.ONE * scale_factor)
	if illustrated:
		draw_texture_rect(LOGO, Rect2(720, 85, 480, LOGO.get_height() * 480.0 / LOGO.get_width()), false)
	else:
		draw_arc(Vector2(640, 285), 26, spin, spin + TAU * .72, 40, CYAN, 4, true)
	if title != "":
		_centered(Vector2(640, 556 if illustrated else 356), title, 30, WHITE, FONT)
	var bar := Rect2(Vector2(340, 580 if illustrated else 386), Vector2(600, 10))
	draw_rect(bar, Color(0.15, 0.24, 0.32, 0.9))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), CYAN)
	draw_rect(
		Rect2(bar.position + Vector2(bar.size.x * progress - 26, 0), Vector2(26, bar.size.y)).intersection(bar),
		Color(0.8, 0.98, 1, 0.9)
	)
	_centered(Vector2(640, 620 if illustrated else 430), STEPS[step], 18, CYAN, FONT)
	if illustrated:
		_centered(Vector2(640, 665), TIPS[tip], 16, Color(.72, .8, .88), FONT)
	_centered(Vector2(1140, 700), AppVersion.label(), 18, Color("b2cbd8"), FONT)


func _centered(pos: Vector2, value: String, size_px: int, color: Color, face: Font) -> void:
	var width := face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(
		face,
		pos - Vector2(width * 0.5, 0) + Vector2(0.5, 1.5),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size_px,
		3,
		Color(0.02, 0.04, 0.07, 0.7)
	)
	draw_string(face, pos - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
