extends RefCounted
const Library = preload("res://scripts/track/route_library.gd")
const Challenge = preload("res://scripts/race/tour_challenge.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const PAINTS := [
	{"name": "FACTORY", "color": "", "goal": "AVAILABLE"},
	{"name": "COAST BLUE", "color": "208eba", "goal": "VISIT 1 DESTINATION"},
	{"name": "SUNSET COPPER", "color": "c97443", "goal": "VISIT 3 DESTINATIONS"},
	{"name": "MIDNIGHT VIOLET", "color": "6d4ba8", "goal": "VISIT ALL 5"},
	{"name": "CLEAN WHITE", "color": "e5e8dc", "goal": "CLEAN TOUR / NO RESETS"}
]
const PLATES := ["STOCK", "TOUR-01", "ALL-05", "CLEAN", "TOUR-16"]
var path := "user://tour_passport.cfg"
var goals: Dictionary = {}
var routes: Dictionary = {}
var paints: Dictionary = {}
var plates: Dictionary = {}
var high_scores: Dictionary = {}
var clean_tour := false
var new_unlocks: Array[String] = []


func load_progress() -> void:
	var file := ConfigFile.new()
	file.load(path)
	goals.clear()
	routes.clear()
	var saved: Variant = file.get_value("progress", "routes", {})
	if saved is Dictionary:
		for route in saved:
			if valid_route(str(route)):
				record_goal(str(route), clampi(int(saved[route]), 0, 3), false)
	clean_tour = bool(file.get_value("progress", "clean_tour", false))
	for field in ["paints", "plates", "high_scores"]:
		var values: Variant = file.get_value("progress", field, {})
		set(field, values.duplicate() if values is Dictionary else {})
	new_unlocks.clear()


static func valid_route(route: String) -> bool:
	return route.length() == 4 and route.replace("L", "").replace("R", "").is_empty()


func record_goal(route: String, medal: int, clean: bool) -> void:
	if not valid_route(route) or medal <= 0:
		return
	var names := unlocked_names()
	var rights := route.count("R")
	var theme: String = Library.THEMES[4][rights]
	goals[theme] = maxi(medal, int(goals.get(theme, 0)))
	routes[route] = maxi(medal, int(routes.get(route, 0)))
	clean_tour = clean_tour or clean
	for name in unlocked_names():
		if name not in names:
			new_unlocks.append(name)


func unlocked_paints() -> Array[int]:
	var result: Array[int] = [0]
	if goals.size() >= 1:
		result.append(1)
	if goals.size() >= 3:
		result.append(2)
	if goals.size() == 5:
		result.append(3)
	if clean_tour:
		result.append(4)
	return result


func unlocked_plates() -> Array[int]:
	var result: Array[int] = [0]
	if goals.size() >= 1:
		result.append(1)
	if goals.size() == 5:
		result.append(2)
	if clean_tour:
		result.append(3)
	if routes.size() == 16:
		result.append(4)
	return result


func unlocked_names() -> Array[String]:
	var result: Array[String] = []
	for index in unlocked_paints():
		result.append(PAINTS[index].name)
	for index in unlocked_plates():
		result.append(PLATES[index])
	return result


func paint_index(vehicle: int) -> int:
	var index := int(paints.get(str(Catalog.spec(vehicle).id), 0))
	return index if index in unlocked_paints() else 0


func plate_index(vehicle: int) -> int:
	var index := int(plates.get(str(Catalog.spec(vehicle).id), 0))
	return index if index in unlocked_plates() else 0


func cycle(vehicle: int, plate: bool) -> void:
	var choices := unlocked_plates() if plate else unlocked_paints()
	var current := plate_index(vehicle) if plate else paint_index(vehicle)
	var next: int = choices[(choices.find(current) + 1) % choices.size()]
	var selected: Dictionary = plates if plate else paints
	selected[str(Catalog.spec(vehicle).id)] = next


func apply_car(car: Node3D, vehicle: int) -> void:
	var paint: String = PAINTS[paint_index(vehicle)].color
	car.apply_customization(
		Color(Catalog.spec(vehicle).paint if paint.is_empty() else paint), PLATES[plate_index(vehicle)]
	)


func finish(race: Node3D) -> void:
	new_unlocks.clear()
	var key: String = race.record_key()
	high_scores[key] = maxi(int(high_scores.get(key, 0)), int(race.score))
	if race.mode == "tour" and race.stage_index == 4 and race.track.history.size() == 4:
		record_goal(
			Challenge.route_id(race.track.history),
			race.run_medal,
			race.wall_hits == 0 and race.traffic_hits == 0 and race.personal_run.recoveries == 0
		)
	if race.save_records:
		save_progress()


func save_progress() -> void:
	var file := ConfigFile.new()
	for field in ["routes", "paints", "plates", "high_scores", "clean_tour"]:
		file.set_value("progress", field, get(field))
	if file.save(path + ".tmp") == OK:
		DirAccess.rename_absolute(path + ".tmp", path)
