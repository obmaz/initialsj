extends AudioStreamPlayer
var race: Node3D
var phase := 0.0
var tone_phase := 0.0
var gain := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Web defaults to sample playback, which cannot play a live generator.
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.22
	stream = generator
	volume_db = -12
	rng.seed = 301

func _process(delta: float) -> void:
	var active: bool = race.state in ["countdown", "racing"] and race.sound_enabled
	gain = move_toward(gain, (0.22 if race.state == "countdown" else 0.36) if active else 0.0, delta * 2)
	if gain <= 0 and not active:
		if playing:
			stop()
		return
	if not playing:
		play()
	var playback: AudioStreamGeneratorPlayback = get_stream_playback()
	if playback == null:
		return
	var gear := clampi(ceili(race.speed / 13), 1, 6)
	var rpm: float = clampf((race.speed - (gear - 1) * 13) / 13, 0, 1)
	var hz := 57.0 + rpm * 75 + gear * 4
	var cue_hz := 0.0
	if active and race.state == "countdown" and ceili(race.countdown) - race.countdown < 0.11:
		cue_hz = 660
	elif active and race.launch_flash > 0.48:
		cue_hz = 1320
	for i in range(playback.get_frames_available()):
		phase = fmod(phase + hz / 22050, 1)
		var engine := sin(phase * TAU) * 0.42 + sin(phase * TAU * 2) * 0.22 + sin(phase * TAU * 4) * 0.10
		var noise := rng.randf_range(-1, 1)
		var tires: float = noise * (0.15 if race.drifting else 0.012)
		var thud: float = (sin(phase * TAU * 0.5) * 0.25 + noise * 0.09) * race.impact
		var wind: float = noise * (0.09 if race.boosting else 0.025) * race.speed / 88
		tone_phase = fmod(tone_phase + cue_hz / 22050, 1)
		var cue := sin(tone_phase * TAU) * 0.6 if cue_hz > 0 else 0.0
		var sample: float = (engine + tires + wind + thud + cue) * gain
		playback.push_frame(Vector2(sample, sample))

func _exit_tree() -> void:
	stop()
