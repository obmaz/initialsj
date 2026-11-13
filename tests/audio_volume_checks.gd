extends RefCounted
const Preferences = preload("res://scripts/audio/audio_preferences.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var config := ConfigFile.new()
	var preferences := Preferences.new()
	preferences.read(config)
	check(preferences.music_volume == 70 and preferences.sound_volume == 50, "기존 저장 파일의 기본 음량은 음악70·효과음50이다")
	for value in [true, "loud", [], NAN, INF]:
		check(Preferences.valid_volume(value, 70) == 70, "잘못된 음량 자료는 기본값으로 복구한다")
	check(Preferences.valid_volume(-5, 70) == 0 and Preferences.valid_volume(150, 70) == 100, "음량 범위는0~100이다")
	var bus_count := AudioServer.bus_count
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "settings"
	race.set_audio_volume(false, 0)
	var index := AudioServer.get_bus_index(race.audio_preferences.effects_bus)
	check(AudioServer.is_bus_mute(index), "효과음0은 UI·충돌·엔진 공통 버스를 완전히 음소거한다")
	check(race.audio_preferences.music_volume == 70, "효과음 조절은 음악 음량을 바꾸지 않는다")
	race.sound_enabled = true
	race.set_audio_volume(false, 50)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(index)), .5), "효과음50은 선형 게인0.5를 적용한다")
	var rect: Rect2 = race.hud.SettingsAudio.slider_rect(race.hud, true)
	var event := InputEventScreenTouch.new()
	event.index = 11
	event.pressed = true
	event.position = race.hud.ui_offset() + rect.get_center() * race.hud.ui_scale()
	race.hud.handle_pointer(event)
	race.hud.move_pointer(
		11, race.hud.ui_offset() + Vector2(rect.end.x + 100, rect.get_center().y) * race.hud.ui_scale()
	)
	check(race.audio_preferences.music_volume == 100, "슬라이더 드래그가 음악 최대100에 도달한다")
	event.pressed = false
	race.hud.handle_pointer(event)
	check(race.hud.audio_drags.is_empty(), "손을 떼면 슬라이더 포인터를 해제한다")
	race.settings_focus = 1
	race.controls.pad_pressed(JOY_BUTTON_DPAD_LEFT)
	check(race.audio_preferences.music_volume == 95, "패드 좌우로 선택된 음량을 조절한다")
	race.preferences_path = "user://audio_volume_checks.cfg"
	race.save_records = true
	race.save_preferences()
	race.set_audio_volume(true, 10, false)
	race.load_preferences()
	check(
		race.audio_preferences.music_volume == 95 and race.audio_preferences.sound_volume == 50, "두 음량을 독립적으로 저장·복원한다"
	)
	DirAccess.remove_absolute(race.preferences_path)
	race.free()
	check(AudioServer.bus_count == bus_count, "씬 종료 시 효과음 버스가 남지 않는다")
	print("음량 기본값·범위·독립 믹싱·슬라이더·패드·저장·버스 해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
