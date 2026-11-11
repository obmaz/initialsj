extends Node3D
# 출발·결승선의 실제 대형 LED 전광판. 가상의 기록을 미리 채우지 않는다.
var road: Node3D
var records: Array[Dictionary] = []
var labels: Array[Label3D] = []
var owner_race: Node3D
const SAVE_GROUP := "speedway_infield_v7_records"
const SAVE_KEY := "top_three_v1"


func _ready() -> void:
	position = road.point(80)
	rotation.y = road.heading(80)
	var dark: StandardMaterial3D = road.material(Color("08121e"))
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var frame: Material = road.material(Color("303f4e"), .55)
	road.box(self, Vector3(0, 18, 0), Vector3(72, 18, 2.4), frame)
	road.box(self, Vector3(0, 18, 1.24), Vector3(70.5, 16.8, .18), dark)
	for side in [-1.0, 1.0]:
		var x: float = side * (road.half_width(80) + road.rail_setback(80, side) + 4)
		road.box(self, Vector3(x, 9, 0), Vector3(1.2, 18, 1.8), frame)
		road.box(self, Vector3(x, .5, 0), Vector3(4, 1, 4), frame)
	for row in range(5):
		var label := Label3D.new()
		label.font = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
		label.font_size = 130 if row in [1, 2, 3] else 104
		label.pixel_size = .022
		label.outline_size = 6
		label.modulate = Color("ffd56b") if row in [0, 4] else Color("c4edff")
		label.position = Vector3(0, 24 - row * 3.0, 1.45)
		label.no_depth_test = false
		add_child(label)
		labels.append(label)
	refresh()


static func stamp(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.---"
	var ticks := roundi(seconds * 1000)
	return "%02d:%02d.%03d" % [ticks / 60000, (ticks / 1000) % 60, ticks % 1000]


func bind(race: Node3D) -> void:
	owner_race = race
	records.clear()
	var file := ConfigFile.new()
	if file.load("user://records.cfg") == OK:
		var saved: Variant = file.get_value(SAVE_GROUP, SAVE_KEY, [])
		if saved is Array:
			for row in saved:
				if row is Dictionary and float(row.get("time", 0)) > 0:
					records.append(row)
	records.sort_custom(func(a, b): return float(a.time) < float(b.time))
	records.resize(mini(records.size(), 3))
	refresh()


func add_result(seconds: float, vehicle: String, persist: bool) -> void:
	if seconds <= 0:
		return
	for row in records:
		if float(row.time) == seconds and str(row.vehicle) == vehicle:
			return
	records.append({"time": seconds, "vehicle": vehicle})
	records.sort_custom(func(a, b): return float(a.time) < float(b.time))
	records.resize(mini(records.size(), 3))
	if persist:
		var file := ConfigFile.new()
		file.load("user://records.cfg")
		file.set_value(SAVE_GROUP, SAVE_KEY, records)
		file.save("user://records.cfg")
	refresh()


func refresh() -> void:
	if labels.size() != 5:
		return
	labels[0].text = "SUNCOAST START/FINISH - 3 LAP RECORDS"
	for i in range(3):
		var row: Dictionary = records[i] if i < records.size() else {}
		labels[i + 1].text = "%d   %s   %s" % [i + 1, str(row.get("vehicle", "---")), stamp(float(row.get("time", 0)))]
	labels[4].text = "YOUR BEST   " + stamp(float(owner_race.best_time) if is_instance_valid(owner_race) else 0.0)
