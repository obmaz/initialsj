extends RefCounted
# 해금된 번호판도 실제 저장·차량에 적용하기 전까지는 샵의 초안으로만 유지한다.
const Shop = preload("res://scripts/ui/tuning/tuning_shop.gd")
const Store = preload("res://scripts/vehicles/customization_store.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func open_shop(race: Node3D) -> CanvasLayer:
	var shop := Shop.new()
	shop.race = race
	shop.vehicle_index = 0
	shop.saved_customization = race.customization.selection(0, race.passport)
	shop.draft_customization = shop.saved_customization.duplicate(true)
	race.tuning_shop = shop
	race.add_child(shop)
	return shop


func run(tree: SceneTree) -> int:
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = false
	race.open_garage()
	race.customization.path = "user://tuning_plate_checks.cfg"
	DirAccess.remove_absolute(race.customization.path)
	race.customization.selections.clear()
	race.passport.goals = {"canyon": 1, "harbor": 1, "bamboo": 1, "snow": 1, "volcano": 1}
	var id: String = race.Catalog.spec(0).id
	race.passport.plates[id] = 1
	race.apply_cosmetics()
	var plates: Dictionary = race.passport.plates.duplicate()
	var shop := open_shop(race)
	check(shop.preview_car.custom_plate == "TOUR-01", "이전 여권의 번호판 선택을 미리보기에서 보존한다")
	shop.options_panel.get_node("PlateChoice").pressed.emit()
	check(shop.draft_customization.plate == 2 and not shop.apply_button.disabled, "번호판 선택도 적용할 수 있는 미저장 초안이다")
	check(
		shop.preview_car.custom_plate == "ALL-05" and race.player.custom_plate == "TOUR-01",
		"번호판 초안은 미리보기만 바꾸고 주행 차량은 보존한다"
	)
	check(
		race.passport.plates == plates and not FileAccess.file_exists(race.customization.path),
		"번호판 탐색만으로 진행이나 파일을 쓰지 않는다"
	)
	shop.request_close()
	check(shop.discard_dialog.visible, "번호판만 바꿔도 폐기 확인이 필요하다")
	shop.discard_dialog.confirmed.emit()
	await tree.process_frame
	check(race.player.custom_plate == "TOUR-01" and race.passport.plates == plates, "취소한 번호판이 실제 차량에 남지 않는다")
	shop = open_shop(race)
	shop.cycle_plate()
	race.customization.read_only = true
	shop.apply_button.pressed.emit()
	check(
		(
			shop.draft_customization.plate == 2
			and shop.saved_customization.plate == -1
			and race.player.custom_plate == "TOUR-01"
		),
		"저장 실패는 번호판 초안만 유지한다"
	)
	race.customization.read_only = false
	shop.apply_button.pressed.emit()
	check(
		shop.saved_customization.plate == 2 and shop.apply_button.disabled and race.player.custom_plate == "ALL-05",
		"적용 성공은 번호판 저장·주행 차·버튼을 함께 갱신한다"
	)
	var reloaded := Store.new()
	reloaded.path = race.customization.path
	reloaded.load_config()
	check(reloaded.selection(0, race.passport).plate == 2, "재실행도 저장한 번호판을 복원한다")
	shop.cycle_plate()
	shop.request_close()
	shop.discard_dialog.confirmed.emit()
	await tree.process_frame
	check(race.player.custom_plate == "ALL-05", "적용 후 다른 번호판 초안을 취소하면 마지막 적용값으로 돌아간다")
	race.cycle_cosmetic(true)
	check(race.player.custom_plate == "STOCK", "빠른 변경도 저장된 튜닝 번호판 다음에서 순환한다")
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 3)
	legacy.set_value("vehicles", id, {"paint": "fb686e"})
	legacy.save(race.customization.path)
	reloaded.load_config()
	check(reloaded.selection(0, race.passport).plate == -1, "스키마 3의 번호판 미지정은 여권 선택을 계속 사용한다")
	DirAccess.remove_absolute(race.customization.path)
	race.free()
	await tree.process_frame
	print("해금 번호판 초안·취소 / 저장 실패·적용·재실행 / 빠른 변경 / 이전 저장 호환: ", "PASS" if failures == 0 else "FAIL")
	return failures
