extends RefCounted
const Art = preload("res://scripts/ui/pre_race_art.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const Layout = preload("res://scripts/ui/menu_layout.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func base_count(paths: Array) -> int:
	var count := 0
	for screen in Art.SCREENS:
		if Art.FILES[screen] in paths:
			count += 1
	return count


func touch(hud: Control, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 71
	event.pressed = true
	event.position = hud.ui_offset() + at * hud.ui_scale()
	hud.handle_pointer(event)
	event.pressed = false
	hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	for path in Art.paths():
		check(ResourceLoader.exists(path), "시작 전 원화·조각 파일이 필요하다: " + path)
		if not ResourceLoader.exists(path):
			continue
		var image := load(path) as Texture2D
		check(image != null, "원화는 실제로 읽을 수 있는 이미지여야 한다: " + path)
		if path.get_file().get_basename() in Art.SCREENS:
			check(image.get_size() == Vector2(1280, 720), "통이미지와 입력의 기준 좌표는1280×720이다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var hud: Control = race.hud
	for iteration in range(3):
		for pair in [["menu", "home"], ["courses", "courses"], ["ready", "garage"], ["settings", "settings"]]:
			race.state = pair[0]
			hud.menus.sync_menu_art()
			check(hud.menus.active_screen == pair[1], "상태와 원화 선택은 함께 바뀐다")
			hud.menus.art(Art.FILES[pair[1]])
			check(base_count(hud.menus.menu_art.keys()) == 1, "반복 진입에서도 통이미지는 현재 화면 한 장만 소유한다")
			check(base_count(Pool.warming.keys()) <= 1, "통이미지 다섯 장을 동시에 미리 읽지 않는다")
	var old_size := tree.root.size
	for viewport in [Vector2i(896, 414), Vector2i(960, 768)]:
		tree.root.size = viewport
		await tree.process_frame
		race.open_menu()
		hud._process(0)
		check(tree.root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "시작 전 배경은 기기 전체에 확장한다")
		touch(hud, hud.HOME_TRACK.get_center())
		check(race.state == "courses", "실제 그림과 같은 좌표로 TRACK 모드를 선택한다")
		touch(hud, hud.COURSE_FUJI.get_center())
		check(race.state == "ready" and race.selected_course == 0, "코스 그림의 투명 입력층은 차량 선택으로 한 번만 연결한다")
		var selected: int = race.selected_vehicle
		touch(hud, hud.garage_card((selected + 1) % 4).get_center())
		check(race.selected_vehicle != selected, "차량 원화 위의 카드는 실제 선택 차량을 바꾼다")
		check(
			hud.GARAGE_BACK == Layout.BACK and hud.GARAGE_START.size.y * hud.ui_scale() >= 44,
			"화면 원화를 바꿔도 공통 뒤로·모바일 출발 버튼 크기를 보존한다"
		)
		race.open_menu()
		touch(hud, hud.HOME_SETTINGS.get_center())
		check(race.state == "settings", "홈 설정 영역이 실제 설정 화면을 연다")
		var previous: bool = race.sound_enabled
		touch(hud, hud.SettingsAudio.toggle_rect(hud, false).get_center())
		check(race.sound_enabled != previous, "설정의 실제 토글이 원화 위에서 한 번만 반응한다")
	tree.root.size = old_size
	race.state = "racing"
	hud._process(0)
	check(tree.root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "주행은 기존 KEEP 비율을 복원한다")
	hud.menus.sync_menu_art()
	check(hud.menus.menu_art.is_empty() and hud.menus.retired_art.is_empty(), "주행 진입에서는 전체 메뉴 원화 참조를 해제한다")
	check(base_count(Pool.warming.keys()) == 0, "주행에 쓰지 않는 통이미지 미리 읽기도 남기지 않는다")
	race.free()
	await tree.process_frame
	print("원화 규격·상태 일치 / 단일 화면 소유·해제 / 폰·폴드 실제 선택·설정 입력: ", "PASS" if failures == 0 else "FAIL")
	return failures
