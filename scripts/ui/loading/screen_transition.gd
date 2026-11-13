extends CanvasLayer
const RaceState = preload("res://scripts/race/race_state.gd")
var busy := false
var race: Node3D
var transition_cover: ColorRect
var transition_sound: AudioStreamPlayer
var loading_overlay: Control
var prepared_road_instance_id := 0


func _ready() -> void:
	layer = 50
	transition_cover = ColorRect.new()
	transition_cover.color = Color(0.02, 0.05, 0.085, 0)
	transition_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_cover.visible = false
	add_child(transition_cover)
	loading_overlay = preload("res://scripts/ui/loading/loading_overlay.gd").new()
	add_child(loading_overlay)
	transition_sound = AudioStreamPlayer.new()
	transition_sound.bus = race.audio_preferences.effects_bus
	transition_sound.stream = preload("res://assets/audio/countdown.wav")
	transition_sound.volume_db = -25
	transition_sound.pitch_scale = 1.25
	transition_sound.playback_type = (
		AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	)
	add_child(transition_sound)


func play(action: Callable) -> void:
	if busy:
		race.loading_title = ""
		return
	busy = true
	# 대기 중 들어온 다른 요청이 진행 중인 전환의 제목을 지우지 못하게 소유한다.
	var loading_title: String = race.loading_title
	race.loading_title = ""
	race.hud.clear_driving_input()
	if race.sound_enabled:
		transition_sound.play()
	transition_cover.visible = true
	var fade_out_seconds := 0.08 if race.motion_reduced else 0.14
	var fade := create_tween()
	fade.tween_property(transition_cover, "color:a", 1.0, fade_out_seconds).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await fade.finished
	await RenderingServer.frame_post_draw
	# 코스 준비가 프레임을 잠시 멈추므로 시작 전에 진행 화면부터 표시한다.
	loading_overlay.begin(
		loading_title if loading_title != "" else "PLEASE WAIT",
		loading_title != "" and loading_title != "COAST CUSTOMS"
	)
	await RenderingServer.frame_post_draw
	loading_overlay.advance(1, .35)
	await RenderingServer.frame_post_draw
	action.call()
	# 출발 카운트다운은 GPU 준비와 화면 공개가 끝난 뒤부터 진행한다.
	var freeze_countdown: bool = (
		race.state == RaceState.COUNTDOWN
		or (race.state == RaceState.PAUSED and race.resume_state == RaceState.COUNTDOWN)
	)
	var was_processing: bool = race.is_physics_processing()
	if freeze_countdown:
		race.set_physics_process(false)
	var storm_pending: bool = race.thunderstorm.eligible() and not race.track.active.has_meta("storm_views_warmed")
	race.warming_world = (
		freeze_countdown and (prepared_road_instance_id != race.track.active.get_instance_id() or storm_pending)
	)
	race.sync_world_rendering()
	if loading_title != "":
		loading_overlay.advance(2, 0.7)
		await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if race.warming_world:
		await preload("res://scripts/rendering/material_warmup.gd").prepare_course(race)
		await race.impacts.prewarm(race.camera)
		await preload("res://scripts/rendering/tunnel_lights.gd").prewarm_scene(race)
		prepared_road_instance_id = race.track.active.get_instance_id()
		race.track.active.set_meta("render_views_warmed", true)
	race.warming_world = false
	loading_overlay.advance(3, 1)
	await RenderingServer.frame_post_draw
	loading_overlay.finish()
	race.hud.modulate.a = 0
	race.hud.position.x = 0 if race.motion_reduced else 22
	var reveal := create_tween().set_parallel(true)
	var fade_in_seconds := 0.10 if race.motion_reduced else 0.22
	reveal.tween_property(transition_cover, "color:a", 0.0, fade_in_seconds)
	reveal.tween_property(race.hud, "modulate:a", 1.0, fade_in_seconds)
	reveal.tween_property(race.hud, "position:x", 0.0, fade_in_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	await reveal.finished
	transition_cover.visible = false
	if freeze_countdown:
		race.set_physics_process(was_processing)
	busy = false
