extends RefCounted
const Car = preload("res://scripts/vehicles/car.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")


# Gameplay and showroom instantiate the exact same model and materials.
static func create(index: int) -> Car:
	var v := Catalog.spec(index)
	var car := Car.new()
	car.model = v.model
	car.paint = Color(v.paint)
	car.nitro_tint = Color(v.accent)
	return car
