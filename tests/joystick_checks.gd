extends RefCounted
const Stick = preload("res://scripts/input/floating_joystick.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func touch(hud: Control, index: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = hud.ui_offset() + at * hud.ui_scale()
	hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	var stick := Stick.new()
	stick.begin(1, Vector2(100, 600), 58)
	check(stick.axis() == 0, "새로 누른 지점은 조향 중립이다")
	stick.move(1, Vector2(129, 600))
	check(stick.axis() > .4 and stick.axis() < .55, "절반 이동은 절반에 가까운 연속 조향이다")
	check(not stick.begin(2, Vector2(200, 600), 58), "두 번째 손가락이 조향 기준점을 바꾸지 않는다")
	stick.move(2, Vector2(-500, 600))
	check(stick.axis() > .4, "다른 손가락은 조향에 영향을 주지 않는다")
	stick.release(2)
	check(stick.active(), "다른 포인터 해제는 조향을 중단하지 않는다")
	stick.release(1)
	stick.begin(-1, Vector2(300, 560), 58)
	check(stick.origin == Vector2(300, 560) and stick.axis() == 0, "다른 곳을 누르면 새 지점에서 중립으로 시작한다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var hud: Control = race.hud
	for mirrored in [false, true]:
		for size in range(3):
			race.state = "racing"
			race.touch_layout.mirrored = mirrored
			race.touch_layout.size_index = size
			hud.clear_driving_input()
			hud.configure_pedals()
			var zone: Rect2 = hud.steering_zone()
			check(
				Rect2(0, 0, 1280, 720).encloses(zone.grow(hud.HudLayout.STICK_RADIUS * race.touch_layout.SIZES[size])),
				"모든 크기·좌우의 생성 범위가 화면 안에 남는다"
			)
			touch(hud, 3, true, zone.get_center())
			hud.move_pointer(
				3, hud.ui_offset() + (zone.get_center() + Vector2(hud.joystick.travel * .5, 0)) * hud.ui_scale()
			)
			check(hud.touch_axis() > .4 and hud.touch_axis() < .55, "실제 터치 좌표가 연속 조향으로 연결된다")
			touch(hud, 4, true, hud.buttons.nitro.get_center())
			check(hud.held("nitro") and hud.touch_axis() > .4, "니트로와 조이스틱은 서로 다른 포인터로 동작한다")
			touch(hud, 4, false, hud.buttons.nitro.get_center())
			race.pause_tour()
			check(not hud.joystick.active() and hud.touch_axis() == 0, "일시정지 때 조향 포인터가 남지 않는다")
	race.nitro_active = false
	race.nitro_burst_left = 0
	race.nitro = 100
	check(hud.nitro_ready(), "연속 니트로는100에서 준비 효과를 켠다")
	race.nitro = 99
	check(not hud.nitro_ready(), "최대 충전이 아니면 준비 효과를 끈다")
	for i in range(Catalog.SPECS.size()):
		if Catalog.spec(i).mode != "charges":
			continue
		race.vehicle = Catalog.spec(i)
		race.nitro_charges = race.vehicle.charges
		check(hud.nitro_ready(), "샷 차량은 최대 충전 개수에서 준비 효과를 켠다")
		race.nitro_active = true
		check(not hud.nitro_ready(), "니트로 사용 중에는 준비 효과를 끈다")
		break
	race.free()
	print("가상 조이스틱 중립·연속 조향·포인터 소유·6배치·재생성·해제 / 니트로 준비: ", "PASS" if failures == 0 else "FAIL")
	return failures
