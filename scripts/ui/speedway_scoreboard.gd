extends Node3D
# 출발·결승선의 실제 대형 LED 전광판. 가상의 기록을 미리 채우지 않는다.
var road: Node3D
var records: Array[Dictionary] = []
var labels: Array[Label3D] = []
var owner_race: Node3D
const SAVE_GROUP := "speedway_infield_v7_records"
const SAVE_KEY := "lap_top_three_v2"
var personal: Dictionary = {}
var last_lap := 0.0
var storage_path := "user://records.cfg"


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


static func stamp(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.---"
	var ticks := roundi(seconds * 1000)
	return "%02d:%02d.%03d" % [ticks / 60000, (ticks / 1000) % 60, ticks % 1000]


func bind(race: Node3D) -> void:
	owner_race = race
	records.clear()
	personal.clear()
	last_lap = 0
	var file := ConfigFile.new()
	if file.load(storage_path) == OK:
		var best: Variant = file.get_value(SAVE_GROUP, "personal_laps_v2", {})
		if best is Dictionary:
			for vehicle in best:
				if vehicle is String and not vehicle.is_empty() and valid_time(best[vehicle]):
					personal[vehicle] = float(best[vehicle])
		var saved: Variant = file.get_value(SAVE_GROUP, SAVE_KEY, [])
		if saved is Array:
			for row in saved:
				if (
					row is Dictionary
					and valid_time(row.get("time"))
					and row.get("vehicle") is String
					and not row.vehicle.is_empty()
				):
					records.append({"time": float(row.time), "vehicle": row.vehicle})
	records.sort_custom(func(a, b): return float(a.time) < float(b.time))
	records.resize(mini(records.size(), 3))
	refresh()


static func valid_time(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0


func add_result(seconds: float, vehicle: String, persist: bool) -> void:
	if not valid_time(seconds) or vehicle.is_empty():
		return
	last_lap = seconds
	personal[vehicle] = minf(seconds, float(personal.get(vehicle, seconds)))
	var duplicate := records.any(func(row): return float(row.time) == seconds and str(row.vehicle) == vehicle)
	if not duplicate:
		records.append({"time": seconds, "vehicle": vehicle})
	records.sort_custom(func(a, b): return float(a.time) < float(b.time))
	records.resize(mini(records.size(), 3))
	if persist:
		var file := ConfigFile.new()
		file.load(storage_path)
		file.set_value(SAVE_GROUP, SAVE_KEY, records)
		file.set_value(SAVE_GROUP, "personal_laps_v2", personal)
		file.save(storage_path)
	refresh()


func refresh() -> void:
	if labels.size() != 5:
		return
	labels[0].text = "LAP RECORDS / LAST " + stamp(last_lap)
	for i in range(3):
		var row: Dictionary = records[i] if i < records.size() else {}
		labels[i + 1].text = "%d   %s   %s" % [i + 1, str(row.get("vehicle", "---")), stamp(float(row.get("time", 0)))]
	var driver: String = str(owner_race.vehicle.name) if is_instance_valid(owner_race) else ""
	labels[4].text = "YOUR BEST LAP   " + stamp(float(personal.get(driver, 0)))
