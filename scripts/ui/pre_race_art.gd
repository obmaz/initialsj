extends RefCounted
# 글자 없는 통이미지와 그 원화에서 잘라낸 조각은 동일한 설계 좌표를 사용한다.
const FILES := {
	"start": "res://assets/ui/pre_race/start.png",
	"home": "res://assets/ui/pre_race/home.png",
	"courses": "res://assets/ui/pre_race/courses.png",
	"garage": "res://assets/ui/pre_race/garage.png",
	"settings": "res://assets/ui/pre_race/settings.png",
	"panel": "res://assets/ui/pre_race/panel.png",
	"button": "res://assets/ui/pre_race/button.png",
	"primary": "res://assets/ui/pre_race/primary.png",
	"header": "res://assets/ui/pre_race/header.png",
}
const SCREENS := ["start", "home", "courses", "garage", "settings"]
const PARTS := ["panel", "button", "primary", "header"]
const DESIGN := Rect2(0, 0, 1280, 720)
const BACKDROP := "res://assets/ui/pre_race/backdrop.png"


static func paths() -> Array[String]:
	var result: Array[String] = [BACKDROP]
	for id in SCREENS + PARTS:
		result.append(FILES[id])
	return result


static func backdrop(hud: Control, mirrored: bool = false) -> void:
	var fill := Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale())
	var image: Texture2D = hud.menus.art(BACKDROP)
	var source := Rect2(Vector2.ZERO, image.get_size())
	var scale_factor := minf(source.size.x / fill.size.x, source.size.y / fill.size.y)
	var cropped := fill.size * scale_factor
	source.position = (source.size - cropped) * .5
	source.size = cropped
	if mirrored:
		fill.position.x = fill.end.x
		fill.size.x *= -1
	hud.draw_texture_rect_region(image, fill, source)


static func background(hud: Control, screen: String, surround: bool = true) -> void:
	assert(screen in SCREENS, "알 수 없는 시작 전 원화 화면: " + screen)
	if surround:
		backdrop(hud, screen == "garage")
	hud.draw_texture_rect(hud.menus.art(FILES[screen]), DESIGN, false)


# 통이미지에 이미 있는 프레임은 덧그리지 않는다. 선택 상태만 별도 얇은 강조로 표시한다.
static func panel(hud: Control, rect: Rect2, _role: String = "panel", selected: bool = false) -> void:
	if selected:
		var outline: PackedVector2Array = hud.MenuTheme.points(rect.grow(-2), 14)
		outline.append(outline[0])
		hud.draw_polyline(outline, Color(.09, .84, .84, .22), 9, true)
		hud.draw_polyline(outline, hud.MenuTheme.TEAL, 2.5, true)


# 원화와 조각의 모서리 두께를 유지하는 독립 프레임. 통이미지를 부분 교체할 때 사용한다.
static func draw_frame(hud: Control, rect: Rect2, role: String = "panel") -> void:
	assert(role in PARTS, "알 수 없는 시작 전 원화 조각: " + role)
	var texture: Texture2D = hud.menus.art(FILES[role])
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var edge := minf(20, minf(floorf(rect.size.x / 3), floorf(rect.size.y / 3)))
	var margin := Vector2.ONE * minf(20, minf(source.size.x, source.size.y) * .25)
	var destination_margin := Vector2.ONE * edge
	var destination_x := PackedFloat32Array(
		[rect.position.x, rect.position.x + destination_margin.x, rect.end.x - destination_margin.x, rect.end.x]
	)
	var destination_y := PackedFloat32Array(
		[rect.position.y, rect.position.y + destination_margin.y, rect.end.y - destination_margin.y, rect.end.y]
	)
	var source_x := PackedFloat32Array([0, margin.x, source.end.x - margin.x, source.end.x])
	var source_y := PackedFloat32Array([0, margin.y, source.end.y - margin.y, source.end.y])
	for row in range(3):
		for column in range(3):
			hud.draw_texture_rect_region(
				texture,
				Rect2(
					destination_x[column],
					destination_y[row],
					destination_x[column + 1] - destination_x[column],
					destination_y[row + 1] - destination_y[row]
				),
				Rect2(
					source_x[column],
					source_y[row],
					source_x[column + 1] - source_x[column],
					source_y[row + 1] - source_y[row]
				)
			)


static func button(hud: Control, rect: Rect2, text: String, size_px: int = 28) -> void:
	hud.MenuTheme.label(hud, rect.grow(-12), text, size_px, hud.MenuTheme.INK, true)
