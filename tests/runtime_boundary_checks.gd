extends RefCounted
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
	var de := Translation.new()
	de.locale = "de"
	de.add_message("EFFECT SLOTS %d / %d", "DE SLOTS %d / %d")
	var ko := Translation.new()
	ko.locale = "ko"
	ko.add_message("EFFECT SLOTS %d / %d", "KO SLOTS %d / %d")
	TranslationServer.add_translation(de)
	TranslationServer.add_translation(ko)
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var shop = load("res://scripts/ui/tuning/tuning_shop.gd").new()
	shop.race = race
	shop.saved_customization = race.customization.selection(0, race.passport)
	shop.draft_customization = shop.saved_customization.duplicate(true)
	race.add_child(shop)
	shop.selected_tab = 4
	shop.rebuild_options()
	await tree.process_frame
	var slot_label: Label = shop.options_panel.get_node("EffectSlots")
	print("BEFORE_LOCALE_CHANGE=", slot_label.text)
	TranslationServer.set_locale("ko")
	await tree.process_frame
	await tree.process_frame
	check(slot_label.text.begins_with("KO SLOTS"), "열린 튜닝샵의 동적 슬롯 문구도 언어 변경을 반영한다")
	shop.refresh_customization()
	print("AFTER_REFRESH=", slot_label.text)
	shop.free()
	TranslationServer.set_locale(original_locale)
	TranslationServer.remove_translation(de)
	TranslationServer.remove_translation(ko)
	check(
		race.hud.time_label(59.9996) == "01:00.000" and race.hud.time_label(119.9996) == "02:00.000",
		"밀리초 반올림은 분 경계를 올바르게 넘긴다"
	)
	race.free()
	await tree.process_frame
	var board = load("res://scripts/ui/speedway_scoreboard.gd").new()
	board.storage_path = "user://review-scoreboard.cfg"
	var config := ConfigFile.new()
	config.set_value(
		board.SAVE_GROUP, board.SAVE_KEY, [{"time": 10.0}, {"time": []}, {"time": 12.0, "vehicle": "VALID"}]
	)
	config.set_value(board.SAVE_GROUP, "personal_laps_v2", {"INVALID": [], "VALID": 12.0})
	config.save(board.storage_path)
	var owner_race := Node3D.new()
	board.bind(owner_race)
	check(board.records.size() == 1 and board.personal == {"VALID": 12.0}, "손상된 기록만 건너뛰고 정상 저장 기록은 보존한다")
	board.add_result(10.0, "NIMORI", false)
	check(board.records.size() == 2, "손상된 저장 파일 이후에도 새 랩 기록을 추가한다")
	DirAccess.remove_absolute(board.storage_path)
	board.free()
	owner_race.free()
	print("번역 / 시간 반올림 / 저장 기록 복원: ", "PASS" if failures == 0 else "FAIL")
	return failures
