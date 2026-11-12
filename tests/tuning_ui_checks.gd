extends RefCounted
const Shop = preload("res://scripts/ui/tuning_shop.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
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
	race.customization.path = "user://tuning_ui_checks.cfg"
	race.customization.selections.clear()
	race.passport.goals.clear()
	race.passport.routes.clear()
	race.passport.clean_tour = false
	var plates: Dictionary = race.passport.plates.duplicate()
	race.cycle_cosmetic(true)
	check(race.passport.plates == plates and race.hud.garage_notice_left > 0, "잠긴 번호판은 같은 값을 저장하는 대신 투어 해금 안내를 표시한다")
	var shop := Shop.new()
	shop.race = race
	shop.saved = Store.defaults(0)
	shop.draft = shop.saved.duplicate(true)
	race.tuning_shop = shop
	race.add_child(shop)
	check(
		shop.apply_button.disabled and shop.car.paint == Color(shop.saved.paint), "샵 진입은 저장값을 미리 보고 변경이 없으면 적용을 비활성화한다"
	)
	for i in range(4):
		shop.tabs[i].pressed.emit()
		check(shop.tab == i, "각 카테고리 버튼은 해당 옵션으로 이동한다")
		await tree.process_frame
		for child in shop.options.get_children():
			if child is Button:
				check(child.position.x + child.size.x <= 274.1, "옵션 컨트롤은 왼쪽 패널 밖으로 늘어나지 않는다")
	shop.tabs[0].pressed.emit()
	for child in shop.options.get_children():
		if (
			child.has_meta("selection_key")
			and child.get_meta("selection_key") == "paint"
			and child.get_meta("selection_value") == "fb686e"
		):
			child.pressed.emit()
	check(shop.car.paint == Color("fb686e") and shop.saved == Store.defaults(0), "팔레트는 실제 미리보기만 변경하고 적용값은 보존한다")
	shop.compare_button.pressed.emit()
	check(shop.comparing and shop.car.paint == Color(shop.saved.paint), "비교는 실제 차량의 마지막 적용 외형을 표시한다")
	shop.compare_button.pressed.emit()
	check(not shop.comparing and shop.car.paint == Color("fb686e"), "비교 해제는 편집 중인 외형으로 복귀한다")
	race.customization.read_only = true
	shop.apply_button.pressed.emit()
	check(
		(
			shop.saved == Store.defaults(0)
			and shop.draft.paint == "fb686e"
			and shop.status.text.begins_with("COULD NOT SAVE")
		),
		"저장 실패는 편집값을 남기고 적용 완료로 표시하지 않는다"
	)
	race.customization.read_only = false
	shop.apply_button.pressed.emit()
	check(
		shop.saved == shop.draft and shop.apply_button.disabled and race.player.paint == Color("fb686e"),
		"적용 성공은 저장값·주행차·버튼 상태를 함께 갱신한다"
	)
	check(race.hud.menus.garage_paint_label() == "PAINT: CUSTOM", "차고는 사용자 도장을 순정 도장으로 잘못 표시하지 않는다")
	var original_rotation := shop.car.rotation.y
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	shop.drag_preview(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.relative = Vector2(20, 0)
	shop.drag_preview(drag)
	check(shop.car.rotation.y == original_rotation, "회전 중인 손가락 외의 터치는 차량을 돌리지 않는다")
	drag.index = 2
	shop.drag_preview(drag)
	check(shop.car.rotation.y > original_rotation, "소유한 터치 드래그는 실제 미리보기를 회전한다")
	shop.choose("paint", "20cbd0")
	shop.request_close()
	check(shop.closing_dialog.visible and is_instance_valid(race.tuning_shop), "미적용 변경이 있으면 차고로 나가기 전에 확인한다")
	var view: WeakRef = weakref(shop.viewport)
	shop.closing_dialog.confirmed.emit()
	await tree.process_frame
	check(race.tuning_shop == null and view.get_ref() == null, "취소 후 샵과 독립 미리보기 뷰포트를 해제한다")
	DirAccess.remove_absolute(race.customization.path)
	race.queue_free()
	await tree.process_frame
	print("튜닝 카테고리·패널 / 팔레트·비교·저장 실패 / 실제 적용 / 멀티터치·취소·해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
