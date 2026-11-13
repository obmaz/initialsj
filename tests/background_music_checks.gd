extends RefCounted
const Music = preload("res://scripts/audio/background_music.gd")
const Catalog = preload("res://scripts/audio/background_music_catalog.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var music := Music.new()
	for mode in ["track", "tour"]:
		var tracks := Catalog.tracks(mode)
		check(tracks.size() >= 2, "트랙·투어는 각각 별도의 음악 목록을 가진다")
		for path in tracks:
			var stream: AudioStreamOggVorbis = load(path)
			check(stream != null and stream.get_length() > 30 and not stream.loop, "음악 원본은 반복 설정 없이 다음 곡으로 이어지는 OGG이다")
		music.mode = mode
		var last := ""
		var cycle: Array[String] = []
		for i in range(tracks.size() * 6):
			var next := music.pick_track()
			check(next in tracks and next != last, "모드별 무작위 목록은 같은 곡을 연속 재생하지 않는다")
			cycle.append(next)
			if cycle.size() == tracks.size():
				var unique := {}
				for path in cycle:
					unique[path] = true
				check(unique.size() == tracks.size(), "한 묶음에서 모든 곡을 중복 없이 재생한다")
				cycle.clear()
			last = next
	check(Catalog.tracks("unknown").is_empty(), "알 수 없는 모드는 다른 모드의 곡을 재생하지 않는다")
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.music_enabled = true
	race.state = "racing"
	music.race = race
	race.add_child(music)
	music.set_process(false)
	music.begin_session("tour")
	race.sound_enabled = false
	check(music.can_play(), "효과음 OFF도 독립적인 배경음악 설정을 끄지 않는다")
	race.music_enabled = false
	check(not music.can_play(), "음악 OFF는 재생을 차단한다")
	music._process(.016)
	check(music.current_path.is_empty(), "음악 OFF 상태로 출발하면 음원 자체를 불러오지 않는다")
	race.music_enabled = true
	music._process(.016)
	for i in range(500):
		music.finish_loading()
		if music.pending_path.is_empty():
			break
		await tree.process_frame
	check(music.voice.stream != null, "선택한 한 곡을 비동기로 준비한다")
	music._process(.016)
	var selected: AudioStream = music.voice.stream
	for state in ["paused", "settings"]:
		race.state = state
		music._process(.016)
		check(not music.can_play() and music.voice.stream_paused, "일시정지·설정 화면에서는 음악도 멈춘다")
		check(music.voice.stream == selected, "잠시 멈춰도 곡을 다시 선택하거나 해제하지 않는다")
	race.state = "racing"
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not music.can_play(), "앱이 배경으로 가면 음악을 차단한다")
	music._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(music.can_play(), "포커스 복귀 후 활성 주행에서만 음악을 재개한다")
	race.state = "menu"
	music._process(.016)
	check(not music.session_active and music.voice.stream == null, "주행에서 메뉴로 나가면 음악 참조를 해제한다")
	race.preferences_path = "user://background_music_checks.cfg"
	race.save_records = true
	race.music_enabled = false
	race.save_preferences()
	race.music_enabled = true
	race.load_preferences()
	check(not race.music_enabled, "음악 OFF 설정은 재시작 후에도 유지된다")
	var config := ConfigFile.new()
	config.set_value("preferences", "music", [])
	config.save(race.preferences_path)
	race.load_preferences()
	check(race.music_enabled, "손상된 음악 설정은 기본 ON으로 복구한다")
	DirAccess.remove_absolute(race.preferences_path)
	race.free()
	await tree.process_frame
	print("모드별 음악 무작위 묶음 / 독립 설정·저장 / 한 곡 스트림 / 일시정지·해제: ", "PASS" if failures == 0 else "FAIL")
	return failures
