extends Node
# 한 곡만 소유한다. 긴 음악은 네이티브 OGG 스트림·웹 미디어 요소로 재생한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const Catalog = preload("res://scripts/audio/background_music_catalog.gd")
const LEVEL := .18
var race: Node3D
var voice := AudioStreamPlayer.new()
var web_music: JavaScriptObject
var mode := ""
var session_active := false
var application_active := true
var bags := {"track": [], "tour": []}
var previous := {"track": "", "tour": ""}
var current_path := ""
var pending_path := ""
var gain := 0.0


func _ready() -> void:
	voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	voice.volume_db = -80
	voice.finished.connect(next_track)
	add_child(voice)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/background_music.js"))
		JavaScriptBridge.eval("window.initialsjMusic = new window.InitialSJMusic();")
		web_music = JavaScriptBridge.get_interface("window").initialsjMusic


func begin_session(next_mode: String) -> void:
	stop_session()
	mode = next_mode
	session_active = true


func pick_track() -> String:
	if not bags.has(mode):
		return ""
	if bags[mode].is_empty():
		bags[mode] = Catalog.tracks(mode)
		bags[mode].shuffle()
		if bags[mode].size() > 1 and bags[mode].back() == previous[mode]:
			var first: String = bags[mode][0]
			bags[mode][0] = bags[mode][-1]
			bags[mode][-1] = first
	if bags[mode].is_empty():
		return ""
	var path: String = bags[mode].pop_back()
	previous[mode] = path
	return path


func next_track() -> void:
	voice.stop()
	voice.stream = null
	current_path = ""
	if web_music != null:
		web_music.clearTrack()


func stop_session() -> void:
	session_active = false
	gain = 0
	next_track()


func can_play() -> bool:
	return (
		session_active
		and application_active
		and race.music_enabled
		and race.audio_preferences.music_volume > 0
		and not race.warming_world
		and (race.screen_transition == null or not race.screen_transition.busy)
		and race.state in RaceState.DRIVING + RaceState.ENDED
	)


func request_track() -> void:
	current_path = pick_track()
	if current_path.is_empty():
		return
	if web_music != null:
		# 웹 내보내기는 원본 OGG를 PCK에 담는다. PCM 전체 디코딩·곡별 캐시는 만들지 않는다.
		web_music.setTrack(Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(current_path)))
	else:
		var error := ResourceLoader.load_threaded_request(current_path, "AudioStreamOggVorbis", false)
		if error == OK:
			pending_path = current_path


func finish_loading() -> void:
	if pending_path.is_empty():
		return
	var status := ResourceLoader.load_threaded_get_status(pending_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var loaded: AudioStreamOggVorbis = ResourceLoader.load_threaded_get(pending_path)
		if session_active and current_path == pending_path:
			voice.stream = loaded
	pending_path = ""


func _process(delta: float) -> void:
	finish_loading()
	if race.state in [RaceState.MENU, RaceState.COURSES, RaceState.READY] and session_active:
		stop_session()
	var active := can_play()
	if active and current_path.is_empty() and pending_path.is_empty():
		request_track()
	gain = move_toward(gain, LEVEL * (.6 if race.state in RaceState.ENDED else 1.0) if active else 0.0, delta * .5)
	if web_music != null:
		if bool(web_music.ended):
			next_track()
		web_music.update(active, gain * race.audio_preferences.music_gain())
	else:
		voice.stream_paused = not active
		voice.volume_db = linear_to_db(maxf(gain * race.audio_preferences.music_gain(), .0001))
		if active and voice.stream != null and not voice.playing:
			voice.play()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		application_active = false
		voice.stream_paused = true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		application_active = true


func _exit_tree() -> void:
	stop_session()
	if not pending_path.is_empty():
		ResourceLoader.load_threaded_get(pending_path)
		pending_path = ""
	if web_music != null:
		web_music.close()
		web_music = null
