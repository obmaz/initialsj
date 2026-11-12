extends RefCounted
# 저장에는 검증한 ID만 남긴다. 슬롯과 호환성의 정본은 차량 모델 정의이다.
const Models = preload("res://models/model_catalog.gd")
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const IDS := ["nitro_blur", "mega_exhaust", "air_spin", "open_top"]
const LABELS := ["NITRO RUSH", "MEGA EXHAUST", "AIR SPIN 360", "OPEN TOP"]
const HELP := [
	"Edge blur while using nitro. Clear road ahead.",
	"Larger flames and beams. Same driving power.",
	"One visual flip above 4 m. Same flight physics.",
	"Open roof with a detailed roadster cabin."
]


static func definition(vehicle: int) -> Resource:
	return Models.find("vehicles", Catalog.spec(vehicle).model)


static func slots(vehicle: int) -> int:
	return clampi(int(definition(vehicle).parameters.get("effect_slots", 1)), 1, 3)


static func supported(id: String, vehicle: int) -> bool:
	return id in IDS and (id != "open_top" or bool(definition(vehicle).parameters.get("open_top", false)))


static func sanitize(value: Variant, vehicle: int) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for id in value:
			if id is String and supported(id, vehicle) and id not in result and result.size() < slots(vehicle):
				result.append(id)
	return result
