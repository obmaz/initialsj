extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.sound_enabled = true
	race.state = "racing"
	race.speed = 65
	var audio: Node
	for child in race.get_children():
		if child.get_script() == load("res://scripts/racing_audio.gd"): audio = child
	assert(audio != null)
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	await create_timer(0.7).timeout
	race.air.launches = 1
	await create_timer(0.4).timeout
	race.air.trick = true
	race.air.landing_flash = 0.65
	await process_frame
	await process_frame
	var cue_used: bool = is_equal_approx(audio.impact_sound.pitch_scale,0.72) and is_equal_approx(audio.impact_sound.volume_db,-21)
	race.air.landing_flash = 0
	await create_timer(0.4).timeout
	race.sound_enabled = false
	await create_timer(1.0).timeout
	record.set_recording_active(false)
	var recording := record.get_recording()
	recording.save_to_wav("user://jump-audio-review.wav")
	var stride := 4 if recording.stereo else 2
	var frames := recording.data.size()/stride
	var peak := 0.0
	var clipped := 0
	var tail_energy := 0.0
	var tail_frames := int(recording.mix_rate*0.12)
	for i in range(frames):
		var left := recording.data.decode_s16(i*stride)/32768.0
		var right := recording.data.decode_s16(i*stride+2)/32768.0 if recording.stereo else left
		peak = maxf(peak,maxf(absf(left),absf(right)))
		if maxf(absf(left),absf(right)) > 0.999: clipped += 1
		if i >= frames-tail_frames: tail_energy += (left*left+right*right)*0.5
	var rms := sqrt(tail_energy/maxi(1,tail_frames))
	var passed := cue_used and peak > 0.02 and clipped == 0 and rms < 0.0001
	var report := {"landing_file_cue_used":cue_used,"peak":peak,"clipped_frames":clipped,"muted_tail_rms":rms,"passed":passed}
	print(JSON.stringify(report))
	FileAccess.open("res://docs/jump-audio-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	AudioServer.remove_bus_effect(0,0)
	race.queue_free()
	await process_frame
	quit(0 if passed else 1)
