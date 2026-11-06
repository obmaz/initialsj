extends SceneTree
const Report = preload("res://tests/report.gd")
# Run with a graphical display and Dummy audio; captures the real audio mixer.
var failures := 0
func _initialize():
	call_deferred("run")
func run():
	if DisplayServer.get_name() == "headless":
		push_error("Audio review requires a graphical display and --audio-driver Dummy; run with ./tools/godot")
		quit(2)
		return
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	var record := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, record)
	record.format = AudioStreamWAV.FORMAT_16_BITS
	record.set_recording_active(true)
	race.state = "racing"
	race.speed = 68
	await create_timer(1.0).timeout
	race.speed = 88
	race.boosting = true
	await create_timer(1.0).timeout
	race.speed = 61
	race.boosting = false
	race.drifting = true
	await create_timer(1.0).timeout
	race.drifting = false
	race.drifts_completed = 1
	await create_timer(0.3).timeout
	race.checkpoint_flash = 1.8
	await create_timer(0.4).timeout
	race.sound_enabled = false
	await create_timer(0.7).timeout
	record.set_recording_active(false)
	var output := record.get_recording()
	output.save_to_wav(Report.path("audio-review.wav"))
	var stride := 4 if output.stereo else 2
	var frames := int(output.data.size() / float(stride))
	var data := output.data
	var peak := 0.0
	var clipped := 0
	var zero_run := 0
	var longest_run := 0
	var tail_energy := 0.0
	var tail_frames := int(output.mix_rate * 0.15)
	for i in range(frames):
		var left := data.decode_s16(i * stride)
		var right := data.decode_s16(i * stride + 2) if output.stereo else left
		var amplitude := maxi(absi(left), absi(right))
		peak = maxf(peak, amplitude / 32768.0)
		if amplitude >= 32760:
			clipped += 1
		if i > output.mix_rate * 0.2 and i < output.mix_rate * 3.1:
			zero_run = zero_run + 1 if amplitude == 0 else 0
			longest_run = maxi(longest_run, zero_run)
		if i >= frames - tail_frames:
			tail_energy += (pow(left / 32768.0, 2) + pow(right / 32768.0, 2)) / 2
	var silence_ms := longest_run * 1000.0 / output.mix_rate
	var tail_rms := sqrt(tail_energy / tail_frames)
	if peak < 0.02 or clipped > 0 or silence_ms > 5 or tail_rms > 0.0001:
		push_error("Audio must be audible, continuous, unclipped and silent after muting")
		failures += 1
	var report := {"peak": snappedf(peak, 0.00001), "clipped_frames": clipped, "longest_active_silent_run_ms": snappedf(silence_ms, 0.001), "muted_tail_rms": snappedf(tail_rms, 0.00001), "failures": failures}
	print(JSON.stringify(report))
	var metrics := FileAccess.open(Report.path("audio-metrics.json"), FileAccess.WRITE)
	metrics.store_string(JSON.stringify(report, "\t") + "\n")
	AudioServer.remove_bus_effect(0, 0)
	race.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
