extends CanvasLayer
const RaceState = preload("res://scripts/race/race_state.gd")
var busy := false
var race: Node3D
var cover: ColorRect
var ui_sound: AudioStreamPlayer
var loading: Control
func _ready() -> void:
	layer = 50
	cover = ColorRect.new()
	cover.color = Color(0.02,0.05,0.085,0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.visible = false
	add_child(cover)
	loading = preload("res://scripts/ui/loading_card.gd").new()
	add_child(loading)
	ui_sound = AudioStreamPlayer.new()
	ui_sound.stream = preload("res://assets/audio/countdown.wav")
	ui_sound.volume_db = -25
	ui_sound.pitch_scale = 1.25
	ui_sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	add_child(ui_sound)
func play(action: Callable) -> void:
	if busy:
		race.loading_title = ""
		return
	busy = true
	race.hud.fingers.clear()
	if race.sound_enabled: ui_sound.play()
	cover.visible = true
	var out_time := 0.08 if race.motion_reduced else 0.14
	var fade := create_tween()
	fade.tween_property(cover,"color:a",1.0,out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade.finished
	await RenderingServer.frame_post_draw
	# Building a course freezes the frame for a moment, so say what is happening first.
	var title: String = race.loading_title
	race.loading_title = ""
	var shown_at := Time.get_ticks_msec()
	if title != "":
		loading.begin(title)
		await RenderingServer.frame_post_draw
		loading.advance(1,0.35)
		await RenderingServer.frame_post_draw
	action.call()
	race.warming_world = race.state == RaceState.READY
	if title != "":
		loading.advance(2,0.7)
		await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if race.warming_world:
		await race.impacts.prewarm(race.camera)
		await preload("res://scripts/rendering/tunnel_lights.gd").prewarm_scene(race)
	race.warming_world = false
	if title != "":
		loading.advance(3,1.0)
		await RenderingServer.frame_post_draw
		# Keep the card readable even when the build was quick.
		var remaining := 0.45-(Time.get_ticks_msec()-shown_at)/1000.0
		if remaining > 0: await get_tree().create_timer(remaining,true,false,true).timeout
		loading.finish()
	race.hud.modulate.a = 0
	race.hud.position.x = 0 if race.motion_reduced else 22
	var reveal := create_tween().set_parallel(true)
	var in_time := 0.10 if race.motion_reduced else 0.22
	reveal.tween_property(cover,"color:a",0.0,in_time)
	reveal.tween_property(race.hud,"modulate:a",1.0,in_time)
	reveal.tween_property(race.hud,"position:x",0.0,in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await reveal.finished
	cover.visible = false
	busy = false
