extends RefCounted
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const Custom = preload("res://scripts/vehicles/vehicle_customization.gd")
const VERSION := 1
var path := "user://vehicle_customization.cfg"
var selections: Dictionary = {}
var read_only := false


static func defaults(vehicle: int) -> Dictionary:
	return {
		"paint": Color(Catalog.spec(vehicle).paint).to_html(false),
		"secondary": "24cbd6",
		"rim": "b7bec4",
		"finish": 0,
		"livery": 0,
		"wheel": 0,
		"wing": 0
	}


static func sanitize(value: Variant, vehicle: int) -> Dictionary:
	var result := defaults(vehicle)
	if not value is Dictionary:
		return result
	for key in ["paint", "secondary", "rim"]:
		if value.get(key) is String and Color.html_is_valid(value[key]):
			result[key] = Color(value[key]).to_html(false)
	for key in ["finish", "livery", "wheel", "wing"]:
		var limit: int = {"finish": 3, "livery": 4, "wheel": 3, "wing": 4}[key]
		if value.get(key) is int and value[key] >= 0 and value[key] < limit:
			result[key] = value[key]
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
	passport.apply_car(car, vehicle)
	Custom.apply(car, selection(vehicle, passport), vehicle)
