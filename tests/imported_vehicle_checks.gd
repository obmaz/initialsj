extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Factory = preload("res://scripts/vehicles/vehicle_factory.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const Traffic = preload("res://scripts/vehicles/tour_traffic_appearance.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func tap(hud: Control, rect: Rect2) -> void:
	var event := InputEventScreenTouch.new()
	event.position = rect.get_center() * hud.ui_scale() + hud.ui_offset()
	event.pressed = true
	hud.handle_pointer(event)
	event.pressed = false
	hud.handle_pointer(event)


func run(tree: SceneTree) -> int:
	var index := -1
	for i in range(Catalog.SPECS.size()):
		if Catalog.spec(i).model == "redcar":
			index = i
	check(index >= 0, "제공한 빨간 세단은 플레이 가능한 차량이다")
	if index < 0:
		return failures
	var car := Factory.create(index)
	tree.root.add_child(car)
	check(car.wheels.size() == 4 and car.headlamp_lenses.size() == 2, "실제 휠 피벗4개와 전조등2개를 연결한다")
	var shell: MeshInstance3D = car.body.get_node("PaintShell")
	var texture: Texture2D = shell.material_override.get_shader_parameter("source_texture")
	check(texture != null and car.body.has_node("TrimShell"), "사진 텍스처와 창·트림을 보존한다")
	car.apply_customization(car.paint, "TOUR-16")
	check(
		car.body.get_children().any(func(node): return node is Label3D and node.text == "TOUR-16"),
		"새 세단의 번호판 선택도 차체에 반영된다"
	)
	var data := Store.defaults(index)
	data.paint = "248edb"
	data.livery = 2
	data.wheel = 1
	data.wing = 2
	Custom.apply(car, data, index)
	check(shell.material_override.get_shader_parameter("source_texture") == texture, "튜닝은 원본 사진 UV·텍스처를 유지한다")
	check(
		(
			shell.material_override.get_shader_parameter("base_paint")
			== Vector4(Color(data.paint).r, Color(data.paint).g, Color(data.paint).b, 1)
		),
		"새 세단의 도장도 실제 재질에 반영된다"
	)
	for wheel in car.wheels:
		check(wheel.has_node("TuningRim") and wheel.has_node("TuningRimInner"), "새 세단의 교체 휠도 좌우 면을 모두 지원한다")
	check(car.active_aero != null and car.aero_rest.origin.y > .5, "교체 윙은 차체 뒤 장착점에 놓인다")
	check(preload("res://scripts/vehicles/effect_items.gd").slots(index) == 2, "새 세단은 효과2슬롯을 지원한다")
	car.set_protection(true)
	check(shell.material_override.get_shader_parameter("protection"), "사진 재질에도 리스폰 보호색을 적용한다")
	car.free()
	var seen := {}
	for stage in range(5):
		for distance in range(0, 1200, 30):
			for passenger in [true, false]:
				seen[Traffic.choose(passenger, distance, stage, 0)] = true
	for id in Traffic.IDS:
		check(seen.has(id), "투어 분산 배치에 새 교통 외형이 포함된다: " + id)
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.open_garage()
	race.select_vehicle(0)
	var hud: Control = race.hud
	tap(hud, hud.GARAGE_PREVIOUS)
	check(race.selected_vehicle == Catalog.SPECS.size() - 1, "왼쪽 화살표는 마지막 차량으로 순환한다")
	check(hud.garage_card(race.selected_vehicle).has_area(), "늘어난 차량도 선택 창 안에 표시된다")
	tap(hud, hud.GARAGE_NEXT)
	check(race.selected_vehicle == 0, "오른쪽 화살표는 첫 차량으로 순환한다")
	for i in range(Catalog.SPECS.size()):
		race.select_vehicle(i)
		check(hud.garage_card(i).size.x >= 230, "차량 수가 늘어도 카드 폭을 유지한다")
	race.free()
	await tree.process_frame
	print("제공 세단 사진·휠·튜닝·무적 / 투어3종 외형 / 차량 선택 창·순환: ", "PASS" if failures == 0 else "FAIL")
	return failures
