extends RefCounted
const Shell = preload("res://scripts/platform/web_shell.gd")


func run(_tree: SceneTree) -> int:
	var failures := 0
	var rect := Rect2(350, 472, 280, 80)
	for dpi in [1.0, 2.0]:
		var transform := Transform2D(0, Vector2.ONE * .575 * dpi, 0, Vector2(80, 0) * dpi)
		var normalized := Shell.normalized_control(rect, 1, Vector2.ZERO, transform, Vector2(896, 414) * dpi)
		var pixels := Rect2(normalized.position * Vector2(896, 414), normalized.size * Vector2(896, 414))
		var expected := Rect2(Vector2(281.25, 271.4), Vector2(161, 46))
		if not pixels.is_equal_approx(expected):
			failures += 1
			push_error("레터박스·DPI가 HTML 버튼과 실제 그림을 어긋나게 하지 않는다")
	print("반폭 fullscreen DOM / 레터박스 원점 / 고해상도 정규화: ", "PASS" if failures == 0 else "FAIL")
	return failures
