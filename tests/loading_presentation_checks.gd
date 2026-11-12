extends RefCounted
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var overlay := preload("res://scripts/ui/loading/loading_overlay.gd").new()
	tree.root.add_child(overlay)
	overlay.begin("SHORT MENU")
	check(overlay.visible and not overlay.show_illustration, "짧은 전환은 이미지 없이 진행 표시로 시작한다")
	overlay.started_at_msec -= 700
	overlay._process(0)
	check(overlay.show_illustration, "예상보다 긴 전환은650ms 뒤 이미지로 전환한다")
	overlay.finish()
	check(not overlay.visible, "준비가 끝나면 로딩을 즉시 닫는다")
	overlay.begin("NEW TRACK", true)
	check(overlay.show_illustration and overlay.load_progress < 1, "무거운 코스는 작업 전에 이미지부터 표시한다")
	overlay.begin("SHORT AGAIN")
	check(not overlay.show_illustration, "다음 짧은 전환에는 이전 이미지 상태가 남지 않는다")
	check(
		(
			overlay.BACKGROUND_ART.get_width() > 1000
			and absf(overlay.BACKGROUND_ART.get_width() / float(overlay.BACKGROUND_ART.get_height()) - 16.0 / 9) < .02
		),
		"스플래시 이미지의 해상도와 가로 비율을 유지한다"
	)
	check(
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot.tscn",
		"실제 시작점은 스플래시를 먼저 그리는 부트 씬이다"
	)
	overlay.free()
	await tree.process_frame
	print("시작 스플래시 / 짧은 진행 표시 / 긴 로딩 자동 전환 / 즉시 종료: ", "PASS" if failures == 0 else "FAIL")
	return failures
