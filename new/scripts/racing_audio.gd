extends AudioStreamPlayer
# The audio mixer owns continuous loops so a slow rendered frame cannot starve the engine.
var race: Node3D
var gain := 0.0
var wind := AudioStreamPlayer.new()
var tires := AudioStreamPlayer.new()
var cue := AudioStreamPlayer.new()
var impact_sound := AudioStreamPlayer.new()
var last_count := 0
var last_launch := 0.0
var last_turbo := 0.0
var last_impact := 0.0
var last_misses := 0
var count_tone: AudioStreamWAV
var launch_tone: AudioStreamWAV
var reward_tone: AudioStreamWAV

func make_wave(kind: String, frames: int, looped: bool, frequency: float = 0) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = PackedByteArray()
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	var filtered := 0.0
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / 22050
		var fraction := float(i) / frames
		var noise := rng.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, 0.10)
		var sample := 0.0
		match kind:
			"engine":
				sample = sin(fraction * TAU) * 0.42 + sin(fraction * TAU * 2) * 0.22 + sin(fraction * TAU * 4) * 0.10
			"wind":
				sample = filtered * 0.7 + noise * 0.08
			"tires":
				sample = (noise - filtered) * 0.35
			"impact":
				sample = (sin(t * TAU * 42) * 0.65 + noise * 0.16) * exp(-t * 16)
			"tone":
				phase += (frequency + (fraction * 480 if frequency == 950 else 0)) / 22050
				var envelope := minf(t / 0.008, 1) * pow(1.0 - fraction, 1.6)
				sample = sin(phase * TAU) * 0.65 * envelope
		data.encode_s16(i * 2, int(clampf(sample, -0.98, 0.98) * 32767))
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames
	return wav

func _ready() -> void:
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	stream = make_wave("engine", 512, true)
	volume_db = -80
	for voice in [wind, tires, cue, impact_sound]:
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
	wind.stream = make_wave("wind", 22050, true)
	tires.stream = make_wave("tires", 22050, true)
	impact_sound.stream = make_wave("impact", 6615, false)
	impact_sound.volume_db = -12
	cue.volume_db = -14
	count_tone = make_wave("tone", 2646, false, 660)
	launch_tone = make_wave("tone", 4851, false, 1320)
	reward_tone = make_wave("tone", 3969, false, 950)

func _process(delta: float) -> void:
	var active: bool = race.state in ["countdown", "racing"] and race.sound_enabled
	var number: int = ceili(race.countdown) if race.state == "countdown" else 0
	if active:
		var tone: AudioStreamWAV
		if number > 0 and number != last_count:
			tone = count_tone
		elif race.launch_flash > last_launch + 0.05:
			tone = launch_tone
		elif race.mini_turbo > last_turbo + 0.05 or race.near_misses > last_misses:
			tone = reward_tone
		if tone != null:
			cue.stream = tone
			cue.play()
		if race.impact > last_impact + 0.05:
			impact_sound.play()
	else:
		cue.stop()
		impact_sound.stop()
	last_count = number
	last_launch = race.launch_flash
	last_turbo = race.mini_turbo
	last_impact = race.impact
	last_misses = race.near_misses
	gain = move_toward(gain, (0.30 if race.state == "countdown" else 0.50) if active else 0.0, delta * 2)
	if gain <= 0 and not active:
		stop()
		wind.stop()
		tires.stop()
		return
	if not playing:
		play()
		wind.play()
		tires.play()
	var gear := clampi(ceili(race.speed / 13), 1, 6)
	var rpm: float = clampf((race.speed - (gear - 1) * 13) / 13, 0, 1)
	var hz := 57.0 + rpm * 75 + gear * 4
	pitch_scale = lerpf(pitch_scale, hz / (22050.0 / 512), 1 - exp(-delta * 12))
	volume_db = -8 + linear_to_db(maxf(gain, 0.0001))
	var wind_gain: float = gain * race.speed / 88 * (0.75 if race.boosting else 0.20)
	wind.volume_db = -8 + linear_to_db(maxf(wind_gain, 0.0001))
	wind.pitch_scale = 0.8 + race.speed / 180
	tires.volume_db = -8 + linear_to_db(maxf(gain * (0.7 if race.drifting else 0.01), 0.0001))

func _exit_tree() -> void:
	stop()
	wind.stop()
	tires.stop()
	cue.stop()
	impact_sound.stop()
