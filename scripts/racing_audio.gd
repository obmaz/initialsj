extends AudioStreamPlayer
# Plays the selected vehicle's own engine, boost and drift sounds (VehicleAudio holds
# the mapping; docs/VEHICLE_AUDIO.md the rules). Loops use native Web Audio looping
# in the browser; transient WAV cues use Godot sample playback. Native builds stream.
# This node itself is the engine loop player.
const VehicleAudio = preload("res://scripts/vehicle_audio.gd")
var race: Node3D
var gain := 0.0
var web_audio
var vehicle := -1
var boost_level := 0.0
var drift_level := 0.0
var last_nitro := false
var drift_sound := AudioStreamPlayer.new()
var boost_sound := AudioStreamPlayer.new()
var start_sound := AudioStreamPlayer.new()
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
	volume_db = -80
	for voice in [drift_sound, boost_sound, start_sound, cue, impact_sound]:
		voice.playback_type = mode
		add_child(voice)
	drift_sound.volume_db = -80
	boost_sound.volume_db = -80
	impact_sound.stream = preload("res://assets/audio/impact.wav")
	impact_sound.volume_db = -15
	cue.volume_db = -18
	if OS.has_feature("web"):
		var source := FileAccess.get_file_as_string("res://web/file_audio.js")
		var recordings := FileAccess.get_file_as_string("res://assets/audio/web-loops.json")
		JavaScriptBridge.eval(source + "\nwindow.initialsjFileAudio = new window.InitialSJFileAudio(" + recordings + ");")
		web_audio = JavaScriptBridge.get_interface("window").initialsjFileAudio
	apply_vehicle()

# Swap all four sounds to the selected vehicle. The garage runs this while silent.
func apply_vehicle() -> void:
	vehicle = race.selected_vehicle
	var p := VehicleAudio.profile(vehicle)
	stream = VehicleAudio.load_loop(p.engine)
	boost_sound.stream = VehicleAudio.load_loop(p.boost)
	drift_sound.stream = VehicleAudio.load_loop(p.drift)
	start_sound.stream = VehicleAudio.load_one_shot(p.boost_start)
	start_sound.volume_db = linear_to_db(VehicleAudio.start_level(vehicle))
	boost_level = 0.0
	drift_level = 0.0
	if web_audio != null: web_audio.setVehicle(VehicleAudio.web_id(vehicle))

func _process(delta: float) -> void:
	if vehicle != race.selected_vehicle: apply_vehicle()
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
		# Each nitro shot, cell or held gauge starts with the vehicle's own ignition hit.
		if race.state == "racing" and race.nitro_active and not last_nitro: start_sound.play()
	else:
		cue.stop()
		impact_sound.stop()
		start_sound.stop()
	last_nitro = race.nitro_active
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
	var mixed := VehicleAudio.mix(race)
	if OS.has_feature("web"):
		if web_audio != null:
			web_audio.update(active, mixed.engine_pitch, mixed.engine, mixed.boost, mixed.boost_pitch, mixed.drift, mixed.drift_pitch)
		return
	gain = move_toward(gain, 1.0 if active else 0.0, delta * 2)
	if gain <= 0 and not active:
		stop()
		drift_sound.stop()
		boost_sound.stop()
		return
	# Short smoothing, like the Web Audio gain ramps, so a shot or a drift never clicks in.
	var follow := 1 - exp(-delta * 28)
	boost_level = lerpf(boost_level, float(mixed.boost) * gain, follow)
	drift_level = lerpf(drift_level, float(mixed.drift) * gain, follow)
	pitch_scale = lerpf(pitch_scale, mixed.engine_pitch, 1 - exp(-delta * 9))
	volume_db = linear_to_db(maxf(float(mixed.engine) * gain, 0.0001))
	boost_sound.pitch_scale = mixed.boost_pitch
	boost_sound.volume_db = linear_to_db(maxf(boost_level, 0.0001))
	drift_sound.pitch_scale = mixed.drift_pitch
	drift_sound.volume_db = linear_to_db(maxf(drift_level, 0.0001))
	if not playing:
		play()
		drift_sound.play()
		boost_sound.play()

func _exit_tree() -> void:
	if web_audio != null:
		web_audio.close()
	stop()
	drift_sound.stop()
	boost_sound.stop()
	start_sound.stop()
	cue.stop()
	impact_sound.stop()
