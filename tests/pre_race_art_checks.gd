extends RefCounted
const Art = preload("res://scripts/ui/rev3_art.gd")
const State = preload("res://scripts/race/race_state.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func touch(hud: Control, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 71
	event.pressed = true
	event.position = hud.ui_offset() + at * hud.ui_scale()
	hud.handle_pointer(event)
	event.pressed = false
	hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	var data := Art.data()
	for entry in data.screens.values():
		check(not "preview/" in entry.background, "비교 전용 배경을 런타임에서 사용하지 않는다")
		check(entry.background.is_empty() or ResourceLoader.exists(entry.background), "설치된 깨끗한 배경이 존재한다")
	for entry in data.assets.values():
		check(ResourceLoader.exists(entry.path) and not "art_sources/" in entry.path, "게임은 원화 폴더 대신 설치된 에셋을 읽는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	var hud: Control = race.hud
	var old_size := tree.root.size
	for viewport in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(1440, 720), Vector2i(896, 448)]:
		tree.root.size = viewport
		await tree.process_frame
		race.open_menu()
		hud._process(0)
		hud.rev3.sync()
		check(tree.root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "메뉴와 주행은 4:3~2:1 화면 전체를 채운다")
		var source: Rect2 = hud.rev3.rect("track")
		check(
			hud.to_design(hud.ui_offset() + source.get_center() * hud.ui_scale()).is_equal_approx(source.get_center()),
			"그림과 터치가 동일한 안전 영역 변환을 사용한다"
		)
		touch(hud, source.get_center())
		check(race.state == State.COURSES, "원화의 TRACK 버튼이 실제 코스 선택을 연다")
		hud.rev3.sync()
		touch(hud, hud.rev3.rect("next").get_center())
		var pending: int = hud.rev3.pending_course
		check(race.state == State.COURSES and pending == 1, "화살표는 실제 로딩 없이 코스 선택을 변경한다")
		touch(hud, hud.rev3.rect("continue").get_center())
		check(
			race.state == State.READY and race.selected_course == 1 and race.track.active.course_id == 1,
			"계속 버튼은 선택 ID와 일치하는 실제 월드를 로드한다"
		)
		hud.rev3.sync()
		var selected: int = race.selected_vehicle
		touch(hud, hud.rev3.rect("next_vehicle").get_center())
		check(race.selected_vehicle != selected, "실제 차량 화살표가 선택 차량을 변경한다")
		touch(hud, hud.rev3.rect("settings").get_center())
		check(race.state == State.SETTINGS, "차량 화면의 설정도 같은 공용 설정으로 연결한다")
		hud.rev3.sync()
		var enabled: bool = race.music_enabled
		touch(hud, hud.rev3.rect("music_toggle").get_center())
		check(race.music_enabled != enabled, "그림 위의 음악 스위치는 한 번만 반응한다")
		for id in ["back", "done", "controls", "sound_toggle", "music_toggle", "motion", "fps", "auto_acceleration"]:
			var bounds: Rect2 = hud.rev3.touch_rect(id)
			check(
				bounds.size.x * hud.ui_scale() >= 43.99 and bounds.size.y * hud.ui_scale() >= 43.99,
				"작은 휴대폰에서도 실제 메뉴 터치 영역은 44px 이상이다"
			)
			check(hud.top_hud_bounds().encloses(bounds), "확대한 터치 영역도 안전 영역을 벗어나지 않는다")
		for music in [false, true]:
			var slider: Rect2 = hud.SettingsAudio.slider_rect(hud, music)
			check(
				not slider.intersects(hud.rev3.touch_rect("music_toggle" if music else "sound_toggle")),
				"볼륨 드래그와 스위치 영역은 겹치지 않는다"
			)
		race.choose_mode("track", 0)
		race.open_menu()
	for course in [0, 1, 4]:
		race.choose_mode("track", course)
		var actual: Vector3 = race.track.active.point(0)
		var points: PackedVector2Array = hud.rev3.course_points(course)
		check(points[0].distance_to(Vector2(actual.x, actual.z)) < .1, "선택 카드의 코스 선은 실제 월드 ID와 같은 프로필에서 읽는다")
	# 화면 교체 후 이전 배경을 참조하지 않는지 실제 약한 참조로 검사한다.
	var art: RefCounted = hud.rev3.art
	art.begin("start")
	var background: WeakRef = weakref(art.texture(data.screens.start.background))
	art.begin("race_hud")
	await tree.process_frame
	check(background.get_ref() == null and art.retired.is_empty(), "주행 시작 후 메뉴 배경의 GPU 참조가 해제된다")
	tree.root.size = old_size
	race.free()
	await tree.process_frame
	print("rev3 설치 계약 / 4:3·16:9·2:1 입력·안전영역 / 실제 코스 ID / 텍스처 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
