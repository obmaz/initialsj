extends AudioStreamPlayer
# All voices play imported audio files. Web uses Web Audio sample playback,
# independent of Godot's streamed mixer buffer and rendering frame rate.
var race: Node3D
var gain := 0.0
var web_audio
var tires := AudioStreamPlayer.new()
var cue := AudioStreamPlayer.new()
var impact_sound := AudioStreamPlayer.new()
var last_pads := 0
var last_count := 0
var last_launch := 0.0
var last_drifts := 0
var last_impact := 0.0
var last_misses := 0
var last_overtakes := 0
var last_checkpoint := 0.0
var last_ramp := 0
var last_landing := 0.0
const COUNT_TONE = preload("res://assets/audio/countdown.wav")
const LAUNCH_TONE = preload("res://assets/audio/launch.wav")
const REWARD_TONE = preload("res://assets/audio/reward.wav")
const LAP_TONE = preload("res://assets/audio/lap.wav")

func _ready() -> void:
	var mode := AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	playback_type = mode
	stream = preload("res://assets/audio/engine-loop.ogg")
	volume_db = -80
	for voice in [tires, cue, impact_sound]:
		voice.playback_type = mode
		add_child(voice)
	tires.volume_db = -80
	tires.stream = preload("res://assets/audio/tire-squeal.ogg")
	impact_sound.stream = preload("res://assets/audio/impact.wav")
	impact_sound.volume_db = -15
	cue.volume_db = -18
	if OS.has_feature("web"):
		var source := FileAccess.get_file_as_string("res://web/file_audio.js")
		var recordings := FileAccess.get_file_as_string("res://assets/audio/web-loops.json")
		JavaScriptBridge.eval(source + "\nwindow.initialsjFileAudio = new window.InitialSJFileAudio(" + recordings + ");")
		web_audio = JavaScriptBridge.get_interface("window").initialsjFileAudio

func _process(delta: float) -> void:
	var active: bool = race.state in ["countdown", "racing"] and race.sound_enabled
	var number: int = ceili(race.countdown) if race.state == "countdown" else (ceili(race.time_left) if race.state == "racing" and race.mode == "tour" and race.time_left <= 10 else 0)
	if active:
		var tone: AudioStream
		if number > 0 and number != last_count:
			tone = COUNT_TONE
		elif race.launch_flash > last_launch + 0.05:
			tone = LAUNCH_TONE
		elif race.surface.boosts_hit > last_pads:
			tone = LAUNCH_TONE
		elif race.air.launches > last_ramp:
			tone = LAUNCH_TONE
		elif race.checkpoint_flash > last_checkpoint + 0.05:
			tone = LAP_TONE
		elif race.drifts_completed > last_drifts or race.near_misses > last_misses or race.overtakes > last_overtakes:
			tone = REWARD_TONE
		if tone != null:
			cue.stream = tone
			cue.play()
		if race.impact > last_impact + 0.05:
			impact_sound.pitch_scale = 1
			impact_sound.volume_db = -15
			impact_sound.play()
		elif race.air.landing_flash > last_landing+0.05:
			impact_sound.pitch_scale = 0.72
			impact_sound.volume_db = -21 if race.air.trick else -25
			impact_sound.play()
	else:
		cue.stop()
		impact_sound.stop()
	last_pads = race.surface.boosts_hit
	last_count = number
	last_launch = race.launch_flash
	last_drifts = race.drifts_completed
	last_impact = race.impact
	last_misses = race.near_misses
	last_overtakes = race.overtakes
	last_checkpoint = race.checkpoint_flash
	last_ramp = race.air.launches
	last_landing = race.air.landing_flash
	var gear: int = maxi(1,race.gear_number())
	var rpm: float = clampf((race.engine_rpm()-900)/6400,0,1)
	var target_pitch := 0.82+rpm*0.38+(gear-1)*0.075
	if OS.has_feature("web"):
		if web_audio != null:
			web_audio.update(active, target_pitch, (0.075 if race.state == "countdown" else (0.21 if race.boosting else 0.18)), 0.038 if race.drifting else (0.018 if race.surface.wet_time > 0 else 0.0))
		return
	gain = move_toward(gain, (0.30 if race.state == "countdown" else 0.70) if active else 0.0, delta * 2)
	if gain <= 0 and not active:
		stop()
		tires.stop()
		return
	pitch_scale = lerpf(pitch_scale, target_pitch, 1 - exp(-delta * 9))
	volume_db = -12 + (1.5 if race.boosting else 0.0) + linear_to_db(maxf(gain, 0.0001))
	tires.volume_db = -20 + linear_to_db(maxf(gain * (0.55 if race.drifting else (0.25 if race.surface.wet_time > 0 else 0.0)), 0.0001))
	if not playing:
		play()
		tires.play()

func _exit_tree() -> void:
	if web_audio != null:
		web_audio.close()
	stop()
	tires.stop()
	cue.stop()
	impact_sound.stop()
