extends RefCounted
# 메뉴·로딩·네이티브 샵이 같은 안전 영역과 1280×720 설계 좌표를 사용한다.
const DESIGN := Vector2(1280, 720)
const BACK := Rect2(60, 16, 220, 80)
const TOUCH_HEIGHT := 80.0


static func safe_rect(viewport_size: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if not OS.has_feature("android"):
		return full
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0 or screen_size.y <= 0 or not safe.has_area():
		return full
	var tree := Engine.get_main_loop() as SceneTree
	var mapped: Rect2
	if tree != null:
		# 창의 레터박스·실제 화면 원점을 먼저 역변환해 폴드의 빈 여백까지 다시 줄이지 않는다.
		mapped = (tree.root.get_screen_transform().affine_inverse() * safe).intersection(full)
	else:
		var ratio := viewport_size / screen_size
		mapped = Rect2(safe.position * ratio, safe.size * ratio).intersection(full)
	return mapped if mapped.has_area() else full


static func scale_for(rect: Rect2) -> float:
	return minf(rect.size.x / DESIGN.x, rect.size.y / DESIGN.y)


static func origin_for(rect: Rect2) -> Vector2:
	return rect.position + (rect.size - DESIGN * scale_for(rect)) * .5
