extends CanvasLayer
const RaceState = preload("res://scripts/race/race_state.gd")
var busy := false
var race: Node3D
var cover: ColorRect
var ui_sound: AudioStreamPlayer
var loading: Control
var prepared_track_id := 0


func _ready() -> void:
	layer = 50
	cover = ColorRect.new()
	cover.color = Color(0.02, 0.05, 0.085, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.visible = false
	add_child(cover)
	loading = preload("res://scripts/ui/loading_card.gd").new()
	add_child(loading)
	ui_sound = AudioStreamPlayer.new()
	ui_sound.stream = preload("res://assets/audio/countdown.wav")
	ui_sound.volume_db = -25
	ui_sound.pitch_scale = 1.25
	ui_sound.playback_type = (
		AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	)
	add_child(ui_sound)


func play(action: Callable) -> void:
	if busy:
		race.loading_title = ""
		return
	busy = true
	# 대기 중 들어온 다른 요청이 진행 중인 전환의 제목을 지우지 못하게 소유한다.
	var title: String = race.loading_title
	race.loading_title = ""
	race.hud.fingers.clear()
	if race.sound_enabled:
		ui_sound.play()
	cover.visible = true
	var out_time := 0.08 if race.motion_reduced else 0.14
	var fade := create_tween()
	fade.tween_property(cover, "color:a", 1.0, out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade.finished
	await RenderingServer.frame_post_draw
	# Building a course freezes the frame for a moment, so say what is happening first.
	loading.begin(title if title != "" else "PLEASE WAIT", title != "" and title != "COAST CUSTOMS")
	await RenderingServer.frame_post_draw
	loading.advance(1, .35)
	await RenderingServer.frame_post_draw
	action.call()
	race.warming_world = race.state == RaceState.READY and prepared_track_id != race.track.get_instance_id()
	if title != "":
		loading.advance(2, 0.7)
		await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if race.warming_world:
		await preload("res://scripts/rendering/material_warmup.gd").prepare_course(race)
		await race.impacts.prewarm(race.camera)
		await preload("res://scripts/rendering/tunnel_lights.gd").prewarm_scene(race)
		prepared_track_id = race.track.get_instance_id()
	race.warming_world = false
	loading.advance(3, 1)
	await RenderingServer.frame_post_draw
	loading.finish()
	race.hud.modulate.a = 0
	race.hud.position.x = 0 if race.motion_reduced else 22
	var reveal := create_tween().set_parallel(true)
	var in_time := 0.10 if race.motion_reduced else 0.22
	reveal.tween_property(cover, "color:a", 0.0, in_time)
	reveal.tween_property(race.hud, "modulate:a", 1.0, in_time)
	reveal.tween_property(race.hud, "position:x", 0.0, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await reveal.finished
	cover.visible = false
	busy = false
