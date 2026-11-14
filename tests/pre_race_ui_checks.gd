extends RefCounted
const Layout = preload("res://scripts/ui/menu_layout.gd")
const Shop = preload("res://scripts/ui/tuning/tuning_shop.gd")
const Nitro = preload("res://scripts/race/nitro_system.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.open_garage()
	var shop := Shop.new()
	shop.race = race
	shop.saved_customization = race.customization.selection(0, race.passport)
	shop.draft_customization = shop.saved_customization.duplicate(true)
	race.tuning_shop = shop
	race.add_child(shop)
	var previous_size := tree.root.size
	for size in [Vector2i(896, 414), Vector2i(1768, 1440)]:
		tree.root.size = size
		shop._process(0)
		var factor := Layout.scale_for(Layout.safe_rect(size))
		check(
			shop.content_root.get_node("Back").position == race.hud.GARAGE_BACK.position,
			"샵·트랙·차량 선택의 뒤로가기는 같은 좌표를 사용한다"
		)
		for button in shop.tab_buttons + [shop.apply_button, shop.compare_button, shop.boost_button]:
			check(button.size.y * factor >= 44, "작은 가로 화면에서도 샵 조작은44픽셀 이상의 높이다")
		for sheet in [shop.color_sheet, shop.discard_dialog]:
			check(
				Layout.safe_rect(shop.get_viewport().get_visible_rect().size).encloses(sheet.get_global_rect()),
				"모달은 OS 창 최소 크기와 무관하게 안전 영역 안에 표시된다"
			)
	shop.open_custom_color("paint")
	check(shop.content_root.get_node("Back").focus_mode == Control.FOCUS_NONE, "색상 모달이 열리면 배경 버튼은 패드·키보드 포커스를 받지 않는다")
	shop.custom_picker.color_changed.emit(Color("fb686e"))
	check(
		shop.draft_customization.paint == "fb686e" and shop.saved_customization.paint != "fb686e", "사용자 색상은 미리보기만 변경한다"
	)
	shop.request_close()
	check(not shop.color_sheet.visible and not shop.discard_dialog.visible, "뒤로가기는 색상 모달만 먼저 닫는다")
	check(shop.draft_customization.paint == shop.saved_customization.paint, "색상 팝업 취소는 진입 전 색상을 복구한다")
	shop.set_customization_value("paint", "fb686e")
	shop.request_close()
	check(shop.discard_keep.has_focus(), "변경 폐기 창은 계속 편집하기에 포커스를 준다")
	check(shop.discard_dialog.visible, "편집값이 남으면 같은 배율의 변경 폐기 모달을 연다")
	shop.discard_dialog.hide()
	shop.discard()
	await tree.process_frame
	tree.root.size = previous_size
	var body = race.player
	body.update_protection(.9)
	var material: ShaderMaterial = body.protection_materials.values()[0]
	var amount: float = material.get_shader_parameter("protection_amount")
	body.update_protection(.05)
	check(material.get_shader_parameter("protection_amount") < amount, "무적 마지막 구간은 점멸하면서 원래 색에 가까워진다")
	body.update_protection(0)
	check(
		not body.protection_active and body.protection_parts[0].material_override == body.protection_originals[0],
		"무적 종료는 복사 재질을 남기지 않고 원래 재질로 돌아간다"
	)
	for i in range(Catalog.SPECS.size()):
		if Catalog.spec(i).mode != "charges":
			continue
		race.selected_vehicle = i
		race.vehicle = Catalog.spec(i)
		race.reset_nitro()
		race.nitro_charges = 0
		race.speed = 50
		race.impact = 0
		race.braking = false
		race.drifting = false
		race.throttling = true
		for tick in range(1501):
			Nitro.update(race, 1.0 / 60, true, false)
		check(race.nitro_charges == 1 and race.nitro_burst_left == 0, "빈 니트로를 계속 누르면 주행 충전만 하고 자동 발사하지 않는다")
		Nitro.update(race, .016, false, false)
		Nitro.update(race, .016, true, false)
		check(race.nitro_charges == 0 and race.nitro_active, "충전된 샷은 새로운 누름에 한 개씩 사용한다")
		break
	race.free()
	await tree.process_frame
	print("시작 전 모바일 안전영역·샵 모달 / 무적 감쇠 / 샷 충전: ", "PASS" if failures == 0 else "FAIL")
	return failures
