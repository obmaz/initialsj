extends RefCounted
# 10Hz 위치 기록과 구간 기록. 디스크 접근은 메뉴 준비·경기 종료에만 한다.
const Challenge = preload("res://scripts/race/tour_challenge.gd")
const STRIDE := 9
const MAX_SAMPLES := 6000
const INTERVAL := 0.1
var directory := "user://personal_runs"
var store := ConfigFile.new()
var context := ""
var reference_route := ""
var reference_key := ""
var samples := PackedFloat32Array()
var reference := PackedFloat32Array()
var best_sectors: Dictionary = {}
var split_delta := 0.0
var split_time := 0.0
var split_flash := 0.0
var split_new := false
var split_label := ""
var cursor := 0
var capped := false
var scope := ""
var scope_stage := -1
var next_sector := 1
var sector_started := 0.0
var last_progress := 0.0
var last_elapsed := 0.0
var segment_valid := true
var recoveries := 0


func prepare(race: Node3D) -> void:
	store = ConfigFile.new()
	store.load(directory.path_join("index.cfg"))
	context = "%s_%s_%d" % [race.mode, race.vehicle.id, race.selected_course if race.mode == "track" else 0]
	var saved_sectors: Variant = store.get_value("sectors", context, {})
	best_sectors = saved_sectors.duplicate() if saved_sectors is Dictionary else {}
	reference_route = str(store.get_value("tour_routes", str(race.vehicle.id), "LLLL"))
	reference_key = race.record_key()
	if race.mode == "tour":
		reference_key = "tour_routes_v2_" + str(race.vehicle.id) + "_" + reference_route
	reference.clear()
	var file := FileAccess.open_compressed(file_path(reference_key), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file != null and file.get_length() < 3_000_000:
		var data: Variant = file.get_var(false)
		if data is Dictionary and data.get("version") == 1 and data.get("key") == reference_key:
			var poses: Variant = data.get("samples")
			if valid_samples(poses):
				reference = poses
	if file != null:
		file.close()
	samples.clear()
	capped = false
	cursor = 0
	scope = ""
	scope_stage = -1
	next_sector = 1
	sector_started = 0
	last_progress = 0
	last_elapsed = 0
	segment_valid = true
	split_flash = 0
	recoveries = 0


func file_path(key: String) -> String:
	return directory.path_join(key.sha256_text().substr(0, 24) + ".run")


static func valid_samples(value: Variant) -> bool:
	if not value is PackedFloat32Array or value.size() < STRIDE * 2 or value.size() % STRIDE != 0:
		return false
	if value.size() > MAX_SAMPLES * STRIDE:
		return false
	var previous := -1.0
	for offset in range(0, value.size(), STRIDE):
		for part in range(STRIDE):
			if not is_finite(value[offset + part]):
				return false
		if value[offset] <= previous:
			return false
		previous = value[offset]
		var quaternion := Quaternion(value[offset + 5], value[offset + 6], value[offset + 7], value[offset + 8])
		if absf(quaternion.length_squared() - 1) > 0.05:
			return false
	return true


func sample(race: Node3D, force: bool = false) -> void:
	if samples.size() / STRIDE >= MAX_SAMPLES:
		capped = true
		return
	if not samples.is_empty():
		var dt: float = race.elapsed - samples[samples.size() - STRIDE]
		if dt <= 0 or (not force and dt < INTERVAL):
			return
	var pose: Transform3D = race.world_race.frame(race.world_race.player_body, race.player)
	var rotation := pose.basis.get_rotation_quaternion().normalized()
	samples.append_array(
		PackedFloat32Array(
			[
				race.elapsed,
				race.completed_distance + race.distance,
				pose.origin.x,
				pose.origin.y,
				pose.origin.z,
				rotation.x,
				rotation.y,
				rotation.z,
				rotation.w
			]
		)
	)


func invalidate() -> void:
	segment_valid = false
	recoveries += 1


func observe(race: Node3D, valid: bool, delta: float) -> void:
	split_flash = maxf(0, split_flash - delta)
	sample(race)
	var current_scope: String = (
		"track" if race.mode == "track" else (Challenge.route_id(race.track.history) + ":" + str(race.stage_index))
	)
	var progress: float = race.distance - 80 if race.mode == "track" else race.distance
	if current_scope != scope:
		var reconsidered: bool = not scope.is_empty() and race.mode == "tour" and scope_stage == race.stage_index
		scope_stage = race.stage_index
		scope = current_scope
		next_sector = 1
		sector_started = 0 if race.stage_index == 0 or race.mode == "track" else race.elapsed
		last_progress = progress
		last_elapsed = race.elapsed
		segment_valid = not reconsidered
	if not valid or progress < last_progress - 2 or progress - last_progress > race.speed * delta * 2 + 10:
		segment_valid = false
	var third: float = race.track.length / 3
	var limit := 9 if race.mode == "track" else 3
	while next_sector <= limit and progress >= next_sector * third:
		var fraction := clampf((next_sector * third - last_progress) / maxf(.001, progress - last_progress), 0, 1)
		var crossed := lerpf(last_elapsed, race.elapsed, fraction)
		var duration := crossed - sector_started
		var key := (
			"%s:%d%s" % [scope, (next_sector - 1) % 3, ":launch" if next_sector == 1 and race.mode == "track" else ""]
		)
		if segment_valid and valid and duration > 1:
			var previous: float = best_sectors.get(key, 0.0)
			split_time = duration
			split_delta = duration - previous if previous > 0 else 0.0
			split_new = previous <= 0 or duration < previous
			split_label = "SECTOR %d" % (((next_sector - 1) % 3) + 1)
			split_flash = 4
			if split_new:
				best_sectors[key] = duration
		sector_started = crossed
		segment_valid = valid
		next_sector += 1
	last_progress = progress
	last_elapsed = race.elapsed


func matches(history: Array) -> bool:
	if reference_route.length() != 4:
		return false
	for i in range(history.size()):
		if i >= 4 or reference_route[i] != ("L" if int(history[i]) == 0 else "R"):
			return false
	return true


func reference_pose(seconds: float) -> Variant:
	if reference.is_empty() or seconds < reference[0] or seconds > reference[reference.size() - STRIDE]:
		return null
	if seconds < reference[cursor]:
		cursor = 0
	while cursor + STRIDE * 2 <= reference.size() and reference[cursor + STRIDE] < seconds:
		cursor += STRIDE
	if cursor + STRIDE * 2 > reference.size():
		return null
	var next := cursor + STRIDE
	var start := Vector3(reference[cursor + 2], reference[cursor + 3], reference[cursor + 4])
	var end := Vector3(reference[next + 2], reference[next + 3], reference[next + 4])
	# 복구로 이동한 구간은 보간하지 않아 공중을 가로지르는 표시를 막는다.
	if start.distance_squared_to(end) > 35 * 35:
		return null
	var amount := clampf((seconds - reference[cursor]) / maxf(.001, reference[next] - reference[cursor]), 0, 1)
	var q1 := (
		Quaternion(reference[cursor + 5], reference[cursor + 6], reference[cursor + 7], reference[cursor + 8])
		. normalized()
	)
	var q2 := (
		Quaternion(reference[next + 5], reference[next + 6], reference[next + 7], reference[next + 8]).normalized()
	)
	return Transform3D(Basis(q1.slerp(q2, amount)), start.lerp(end, amount))


func finish(race: Node3D, success: bool) -> void:
	if not race.save_records:
		return
	DirAccess.make_dir_recursive_absolute(directory)
	store.set_value("sectors", context, best_sectors)
	if success and race.mode == "tour" and race.track.history.size() == 4:
		store.set_value("tour_routes", str(race.vehicle.id), Challenge.route_id(race.track.history))
	var index_path := directory.path_join("index.cfg")
	if store.save(index_path + ".tmp") != OK:
		return
	if DirAccess.rename_absolute(index_path + ".tmp", index_path) != OK:
		return
	if not success or not race.new_record or capped:
		return
	sample(race, true)
	if capped or not valid_samples(samples):
		return
	var path := file_path(race.record_key())
	var file := FileAccess.open_compressed(path + ".tmp", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return
	file.store_var({"version": 1, "key": race.record_key(), "samples": samples})
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
