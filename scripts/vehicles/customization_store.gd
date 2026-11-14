extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Effects = preload("res://scripts/vehicles/effect_items.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const VERSION := 4
const Passport = preload("res://scripts/race/tour_passport.gd")
var path := "user://vehicle_customization.cfg"
var selections: Dictionary = {}
var read_only := false


static func defaults(vehicle: int) -> Dictionary:
	return {
		"paint": Color(Catalog.spec(vehicle).paint).to_html(false),
		"secondary": "24cbd6",
		"rim": "b7bec4",
		"finish": 0,
		"shading": 0,
		"toon_strength": 80,
		"livery": 0,
		"wheel": 0,
		"wing": 0,
		"effects": [],
		"plate": -1
	}


static func sanitize(value: Variant, vehicle: int) -> Dictionary:
	var result := defaults(vehicle)
	if not value is Dictionary:
		return result
	for key in ["paint", "secondary", "rim"]:
		if value.get(key) is String and Color.html_is_valid(value[key]):
			result[key] = Color(value[key]).to_html(false)
	for key in ["finish", "livery", "wheel", "wing", "shading"]:
		var limit: int = {"finish": 3, "livery": 4, "wheel": 3, "wing": 4, "shading": 2}[key]
		if value.get(key) is int and value[key] >= 0 and value[key] < limit:
			result[key] = value[key]
	if value.get("toon_strength") is int:
		result.toon_strength = clampi(value.toon_strength, 0, 100)
	if value.get("plate") is int and value.plate >= -1 and value.plate < Passport.PLATES.size():
		result.plate = value.plate
	result.effects = Effects.sanitize(value.get("effects", []), vehicle)
	return result


func load_config() -> void:
	selections.clear()
	read_only = false
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var version: Variant = config.get_value("meta", "version", 0)
	if not version is int or version > VERSION:
		read_only = true
		return
	for i in range(Catalog.SPECS.size()):
		var id: String = Catalog.spec(i).id
		if config.has_section_key("vehicles", id):
			selections[id] = sanitize(config.get_value("vehicles", id), i)


func selection(vehicle: int, passport: RefCounted = null) -> Dictionary:
	var id: String = Catalog.spec(vehicle).id
	if selections.has(id):
		return selections[id].duplicate(true)
	var result := defaults(vehicle)
	if passport != null:
		var paint: String = passport.PAINTS[passport.paint_index(vehicle)].color
		if not paint.is_empty():
			result.paint = paint
	return result


func save(vehicle: int, value: Dictionary) -> Error:
	if read_only:
		return ERR_UNAVAILABLE
	var next := selections.duplicate(true)
	next[str(Catalog.spec(vehicle).id)] = sanitize(value, vehicle)
	var config := ConfigFile.new()
	config.set_value("meta", "version", VERSION)
	for id in next:
		config.set_value("vehicles", id, next[id])
	var error := config.save(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK:
		selections = next
	return error


func apply(car: Node3D, vehicle: int, passport: RefCounted) -> void:
	apply_selection(car, selection(vehicle, passport), vehicle, passport)


static func plate_index(value: Dictionary, vehicle: int, passport: RefCounted) -> int:
	var index: int = value.get("plate", -1)
	return index if index in passport.unlocked_plates() else passport.plate_index(vehicle)


static func apply_selection(car: Node3D, value: Dictionary, vehicle: int, passport: RefCounted) -> void:
	# 도장·번호판을 먼저 복원하고 전용 재질·휠·윙을 같은 초안으로 적용한다.
	car.apply_customization(Color(value.paint), passport.PLATES[plate_index(value, vehicle, passport)])
	Custom.apply(car, value, vehicle)
