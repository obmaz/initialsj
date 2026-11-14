extends RefCounted
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func tap(hud: Control, rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 4
	event.pressed = true
	event.position = rect.get_center() * hud.ui_scale() + hud.ui_offset()
	hud.handle_pointer(event)
	event.pressed = false
	hud.handle_pointer(event)


func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * .2126 + linear.g * .7152 + linear.b * .0722


func contrast(a: Color, b: Color) -> float:
	var x := luminance(a)
	var y := luminance(b)
	return (maxf(x, y) + .05) / (minf(x, y) + .05)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	var hud: Control = race.hud
	check(contrast(MenuTheme.INK, MenuTheme.PAPER) > 7, "밝은 패널의 본문은 충분한 명암 대비를 가진다")
	check(
		contrast(MenuTheme.TEAL, MenuTheme.PAPER) > 4.5 and contrast(MenuTheme.MUTED, MenuTheme.PAPER) > 4.5,
		"정보·보조 글자도 흰 패널에서 읽을 수 있어야 한다"
	)
	check(hud.FONT.get_supported_variation_list().size() > 0, "UI 글꼴은 한글과 가변 굵기를 제공한다")
	var old_locale := TranslationServer.get_locale()
	var translation := Translation.new()
	translation.locale = "de"
	translation.add_message("SELECT CAR", "WÄHLE DEIN INDIVIDUELL GESTALTETES RENNSPORTFAHRZEUG")
	translation.add_message("TUNING", "FAHRZEUGINDIVIDUALISIERUNG UND GESTALTUNG")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("de")
	for sample in [["SELECT CAR", 560.0, 40], ["TUNING", 217.0, 28]]:
		var result := MenuTheme.layout_text(hud, sample[0], sample[1], sample[2])
		check(
			(
				result.size >= 22
				and hud.FONT.get_string_size(result.text, HORIZONTAL_ALIGNMENT_LEFT, -1, result.size).x <= sample[1]
			),
			"긴 번역은 읽을 크기를 유지하며 사각형 안에 맞춘다"
		)
	var layout := MenuTheme.layout_text(hud, "SELECT CAR", 560, 40)
	hud.menu_text.begin()
	hud.menu_text.draw(Rect2(330, 18, 560, 66), layout.text, layout.size, MenuTheme.INK, false)
	hud.menu_text.finish()
	check(
		(
			hud.menu_text.labels[0].text == layout.text
			and hud.menu_text.labels[0].mouse_filter == Control.MOUSE_FILTER_IGNORE
		),
		"번역 글자는 실제Label에 표시하고 터치 입력을 가로채지 않는다"
	)
	var label_count: int = hud.menu_text.labels.size()
	hud.menu_text.begin()
	hud.menu_text.finish()
	check(
		not hud.menu_text.labels[0].visible and hud.menu_text.labels.size() == label_count,
		"다른 화면으로 전환하면 글자 풀을 재사용하고 지난 글자는 숨긴다"
	)
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(old_locale)
	var old_size := tree.root.size
	for viewport in [Vector2i(896, 414), Vector2i(2340, 1080), Vector2i(1768, 1440)]:
		tree.root.size = viewport
		await tree.process_frame
		race.open_menu()
		tap(hud, hud.HOME_TRACK)
		check(race.state == "courses", "모바일 화면 비율에서 트랙 선택 터치가 같은 화면으로 연결된다")
		hud.rev3.select_course(2)
		hud.rev3.sync()
		tap(hud, hud.rev3.rect("continue"))
		check(race.state == "ready" and race.selected_course == 2, "코스 카드는 한 번의 터치로 실제 코스·차량 선택에 연결된다")
		tap(hud, hud.garage_card(2))
		check(race.selected_vehicle == 2, "이동한 차량 카드의 그림과 터치 영역이 일치한다")
		for rect in [hud.GARAGE_TUNING, hud.GARAGE_START, hud.COURSE_WEATHER, hud.COURSE_PERIOD]:
			var scale_factor := minf(viewport.x / 1280.0, viewport.y / 720.0)
			check(rect.size.y * scale_factor >= 44, "주요 메뉴 조작은 작은 가로 화면에서도 44픽셀 높이를 확보한다")

		for i in range(4):
			for j in range(i + 1, 4):
				check(not hud.garage_card(i).intersects(hud.garage_card(j)), "차량 카드는 서로의 터치 영역을 덮지 않는다")
		race.state = "finished"
		race.leave_results()
		check(race.state == "courses", "트랙 결과는 밝은 트랙 선택 화면으로 돌아간다")
	race.state = "racing"
	hud.rev3.art.begin("race_hud")
	await tree.process_frame
	check(hud.rev3.art.retired.is_empty(), "생성형 배경·장식은 화면 교체 뒤 이전 참조를 해제한다")
	tree.root.size = old_size
	race.free()
	await tree.process_frame
	print("밝은 메뉴 대비 / 생성형 아틀라스 공유 / 긴 번역 / 모바일 터치·복귀 / 메뉴 자원 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
