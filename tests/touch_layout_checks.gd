extends RefCounted
const Layout = preload("res://scripts/input/touch_layout.gd")
const HudLayout = preload("res://scripts/ui/race_hud_layout.gd")
const ControlsPanel = preload("res://scripts/ui/touch_layout_panel.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	check(HudLayout.PAUSE.position == Vector2.ONE * HudLayout.EDGE, "좌상단은 위·왼쪽 여백이 같다")
	check(
		(
			HudLayout.MINIMAP.position.y == HudLayout.EDGE
			and HudLayout.DESIGN.x - HudLayout.MINIMAP.end.x == HudLayout.EDGE
		),
		"투어·트랙 공통 미니맵은 위·오른쪽 여백이 같다"
	)
	for bounds in [Rect2(-80, 20, 160, 300), Rect2(30, -50, 1200, 80), Rect2()]:
		for point in [bounds.position, bounds.end, bounds.get_center(), Vector2(100000, -100000)]:
			check(
				(
					HudLayout.project_map(point, bounds).distance_to(HudLayout.MINIMAP.get_center())
					<= HudLayout.MAP_RADIUS + .001
				),
				"코스와 도로 밖 차량 표시가 원형 미니맵 내부에 남는다"
			)
	for row in range(5):
		for node in range(row + 1):
			check(
				HudLayout.route_point(row, node).distance_to(HudLayout.MINIMAP.get_center()) <= HudLayout.MAP_RADIUS,
				"투어 15개 지역이 트랙과 같은 원형 프레임 안에 들어간다"
			)
	var layout := Layout.new()
	var config := ConfigFile.new()
	for value in ["bad", true, -1, 3, 100]:
		config.set_value("touch_layout", "size", value)
		layout.read(config)
		check(layout.size_index == 1, "손상된 크기는 기본값으로 복원한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for mirrored in [false, true]:
		for size in range(3):
			race.touch_layout.mirrored = mirrored
			race.touch_layout.size_index = size
			for auto in [false, true]:
				race.auto_accelerate = auto
				race.hud.configure_pedals()
				var buttons: Dictionary = race.hud.buttons
				check(buttons.left.position.x < buttons.right.position.x, "반전 후에도 좌우 화살표 순서를 유지한다")
				check(
					buttons.left.get_center().x > 640 if mirrored else buttons.left.get_center().x < 640,
					"조향 그룹이 선택한 쪽에 있다"
				)
				for action in buttons:
					var rect: Rect2 = buttons[action]
					if action != "pause":
						check(rect.size.x >= 96 and rect.size.y >= 96, "작은 배치도 기본 액션 터치 크기를 확보한다")
					check(Rect2(0, 0, 1280, 720).encloses(rect), "커진 버튼이 안전 설계 영역을 벗어나지 않는다")
				var at: Vector2 = buttons.gas.get_center()
				check(race.hud.button_at(at) == ("brake" if auto else "gas"), "그려진 페달 위치의 의미가 자동 가속과 일치한다")
				var pair: Vector2 = (buttons.left.get_center() + buttons.right.get_center()) * .5
				check(
					not (race.hud.hit_button("left", pair) and race.hud.hit_button("right", pair)),
					"한 포인터가 두 조향을 누르지 않는다"
				)
	race.state = "settings"
	race.hud.open_controls()
	ControlsPanel.press(race.hud, ControlsPanel.SIDE[1].get_center())
	ControlsPanel.press(race.hud, ControlsPanel.SIZE[2].get_center())
	check(race.touch_layout.mirrored and race.touch_layout.size_index == 2, "실제 설정 입력이 배치를 바꾼다")
	race.touch_layout.write(config)
	layout.read(config)
	check(layout.mirrored and layout.size_index == 2, "설정 저장 형식이 배치를 보존한다")
	ControlsPanel.press(race.hud, ControlsPanel.RESET.get_center())
	check(not race.touch_layout.mirrored and race.touch_layout.size_index == 1, "초기화는 검증된 기본 배치로 돌아간다")
	race.close_settings()
	check(race.state == "settings" and not race.hud.controls_open, "뒤로 가기는 조작 설정만 닫는다")
	for index in range(3):
		check(
			race.hud.menus.graphics_index(race.hud.menus.graphics_segment(index).get_center()) == index,
			"표시된 그래픽 세그먼트가 실제 선택값과 맞는다"
		)
	check(
		race.hud.menus.graphics_index(race.hud.SETTINGS_GRAPHICS.position + Vector2(12, 40)) == -1,
		"그래픽 라벨을 누르면 품질 선택을 바꾸지 않는다"
	)
	race.free()
	print("터치 12배치 / 여유 영역 단일 소유 / 반전·크기·안전 영역 / 저장·초기화·뒤로: ", "PASS" if failures == 0 else "FAIL")
	return failures
