extends RefCounted
# Every vehicle owns its engine, boost, boost-start and drift sounds (docs/VEHICLE_AUDIO.md).
# Adding a vehicle without them, or reusing another vehicle's file, fails here.
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const VehicleAudio = preload("res://scripts/audio/vehicle_audio.gd")
const FILE_KEYS := ["engine", "boost", "boost_start", "drift"]
const TUNING_RANGES := {
	"engine_pitch": Vector2(0.5, 1.2),
	"engine_span": Vector2(0.1, 0.8),
	"engine_gear": Vector2(0.0, 0.15),
	"engine_gain": Vector2(0.5, 1.6),
	"boost_gain": Vector2(0.4, 1.6),
	"boost_rise": Vector2(0.0, 0.6),
	"start_gain": Vector2(0.3, 1.6),
	"drift_gain": Vector2(0.4, 1.6),
	"drift_pitch": Vector2(0.7, 1.4)
}
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run(tree: SceneTree) -> int:
	var count: int = Catalog.SPECS.size()
	var bake_recipes := FileAccess.get_file_as_string("res://tools/bake_vehicle_audio.py")
	var web_loops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/web-loops.json"))
	var seen := {}
	var ids := {}
	for index in range(count):
		var id: String = Catalog.spec(index).id
		var profile: Dictionary = VehicleAudio.profile(index)
		ids[id] = true
		check(VehicleAudio.web_id(index) == id, "The Web Audio key must be the vehicle id: " + id)
		check(bake_recipes.contains('"%s": {' % id), "tools/bake_vehicle_audio.py needs a synthesis recipe for " + id)
		# An incomplete profile is reported once; the checks below would only crash on it.
		var absent: Array[String] = []
		for key in FILE_KEYS + TUNING_RANGES.keys():
			if not profile.has(key):
				absent.append(key)
		if not absent.is_empty():
			check(false, id + " audio profile lacks: " + ", ".join(absent))
			continue
		for key in FILE_KEYS:
			var path := str(profile.get(key, ""))
			check(
				path.get_base_dir().ends_with("/assets/audio/vehicles") and path.get_file().begins_with(id + "-"),
				id + " " + key + " must be a file named for the vehicle under assets/audio/vehicles/"
			)
			check(ResourceLoader.exists(path), id + " " + key + " sound is missing: " + path)
			var fingerprint := FileAccess.get_md5(path)
			check(
				not fingerprint.is_empty() and not seen.has(key + fingerprint),
				id + " " + key + " must not reuse another vehicle's recording"
			)
			seen[key + fingerprint] = true
		for key in TUNING_RANGES:
			var value := float(profile.get(key, -1000.0))
			check(
				value >= TUNING_RANGES[key].x and value <= TUNING_RANGES[key].y,
				"%s audio tuning %s is missing or out of range: %s" % [id, key, str(profile.get(key))]
			)
		var loops := {
			"engine": VehicleAudio.load_loop(str(profile.engine)),
			"boost": VehicleAudio.load_loop(str(profile.boost)),
			"drift": VehicleAudio.load_loop(str(profile.drift))
		}
		for key in loops:
			var loop: AudioStream = loops[key]
			check(
				loop is AudioStreamOggVorbis and loop.loop and loop.get_length() >= 1.5,
				id + " " + key + " must load as a looping stream"
			)
			var encoded := str(web_loops.get(id + "-" + key, ""))
			check(
				(
					not encoded.is_empty()
					and Marshalls.base64_to_raw(encoded) == FileAccess.get_file_as_bytes(str(profile[key]))
				),
				"web-loops.json is stale for " + id + " " + key + "; run tools/bake_vehicle_audio.py"
			)
		var start: AudioStream = VehicleAudio.load_one_shot(str(profile.boost_start))
		check(
			start is AudioStreamWAV and start.get_length() > 0.2 and start.get_length() < 1.5,
			id + " boost-start must be a short one-shot"
		)
	check(ids.size() == count, "Vehicle ids must be unique")
	for key in web_loops:
		check(
			ids.has(str(key).rsplit("-", true, 1)[0]),
			"web-loops.json carries a loop for an unknown vehicle: " + str(key)
		)
	if failures > 0:
		print("Per-vehicle engine / boost / ignition / drift sounds, files, web loops and mix: FAIL")
		return failures
	var race = load("res://scenes/race.tscn").instantiate()
	tree.root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.state = "racing"
	race.speed = 60
	for index in range(count):
		race.selected_vehicle = index
		race.nitro_active = false
		race.surface.reset()
		race.drifting = false
		var idle := VehicleAudio.mix(race)
		check(idle.boost == 0.0 and idle.drift == 0.0 and idle.engine > 0.0, "Boost and drift stay silent until used")
		race.nitro_active = true
		var nitro := VehicleAudio.mix(race)
		race.nitro_active = false
		race.surface.pad_time = 1.0
		var pad := VehicleAudio.mix(race)
		race.surface.reset()
		check(
			nitro.boost > 0.0 and pad.boost > 0.0 and pad.boost < nitro.boost,
			"Nitro must roar louder than a road boost pad"
		)
		race.drifting = true
		var drifting := VehicleAudio.mix(race)
		race.drifting = false
		race.surface.wet_time = 1.0
		var puddle := VehicleAudio.mix(race)
		race.surface.reset()
		check(
			drifting.drift > 0.0 and puddle.drift > 0.0 and puddle.drift < drifting.drift,
			"A drift must be louder than puddle hiss"
		)
		race.speed = 25
		var slow := VehicleAudio.mix(race)
		race.speed = 80
		var fast := VehicleAudio.mix(race)
		race.speed = 60
		check(
			(
				fast.engine_pitch > slow.engine_pitch
				and fast.boost_pitch >= slow.boost_pitch
				and fast.drift_pitch > slow.drift_pitch
			),
			"Engine, boost and drift pitch must rise with speed"
		)
		race.state = "countdown"
		check(VehicleAudio.mix(race).engine < idle.engine, "The grid idle must be quieter than racing")
		race.state = "racing"
	# The real player: each selected vehicle swaps in all four of its own sounds, and a nitro
	# shot starts with that vehicle's ignition hit. (Native path; the Web path is web_audio_checks.cjs.)
	var player = preload("res://scripts/audio/racing_audio.gd").new()
	player.race = race
	race.add_child(player)
	race.sound_enabled = true
	race.state = "racing"
	var streams := {}
	for index in range(count):
		race.selected_vehicle = index
		race.nitro_active = false
		player._process(0.1)
		var profile: Dictionary = VehicleAudio.profile(index)
		var id: String = Catalog.spec(index).id
		check(
			(
				player.stream.resource_path == profile.engine
				and player.boost_sound.stream.resource_path == profile.boost
				and player.drift_sound.stream.resource_path == profile.drift
				and player.start_sound.stream.resource_path == profile.boost_start
			),
			id + ": the player must carry all four of the selected vehicle's sounds"
		)
		check(not player.start_sound.playing, id + ": no ignition hit before nitro starts")
		race.nitro_active = true
		race.speed = 70
		for frame in range(8):
			player._process(1.0 / 60)
		check(player.start_sound.playing, id + ": a nitro shot must start with the vehicle's ignition hit")
		check(
			player.boost_sound.volume_db > -40.0 and player.volume_db > -40.0,
			id + ": the booster roar must join the engine"
		)
		race.nitro_active = false
		for frame in range(30):
			player._process(1.0 / 60)
		check(player.boost_sound.volume_db < -50.0, id + ": the booster must fade out when the shot ends")
		race.drifting = true
		for frame in range(30):
			player._process(1.0 / 60)
		check(player.drift_sound.volume_db > -45.0, id + ": the drift sound must play while drifting")
		race.drifting = false
		for key in ["engine", "boost", "drift", "start"]:
			var path: String = {
				"engine": player.stream.resource_path,
				"boost": player.boost_sound.stream.resource_path,
				"drift": player.drift_sound.stream.resource_path,
				"start": player.start_sound.stream.resource_path
			}[key]
			check(not streams.has(path), id + ": " + key + " sound is shared with another vehicle")
			streams[path] = true
	race.sound_enabled = false
	for frame in range(12):
		player._process(0.1)
	check(not player.start_sound.playing, "Muting must stop the ignition hit")
	check(
		not player.playing and not player.boost_sound.playing and not player.drift_sound.playing,
		"Muting must fade out and stop every loop"
	)
	player.queue_free()
	race.queue_free()
	# The mixer thread releases stopped playbacks in real time, which a fixed-FPS run skips past.
	OS.delay_msec(500)
	await tree.process_frame
	print(
		"Per-vehicle engine / boost / ignition / drift sounds, files, web loops and mix: ",
		"PASS" if failures == 0 else "FAIL"
	)
	return failures
