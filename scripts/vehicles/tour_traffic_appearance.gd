extends Node3D
# 투어 교통의 저비용 외형. 물리·계측은 TourTraffic이 소유하고 모델 팩은 정적 GLB만 제공한다.
const Catalog = preload("res://models/model_catalog.gd")
const Pool = preload("res://scripts/rendering/render_resources.gd")
const IDS := ["icecream_car", "bike", "dumptruck"]
const PATHS := [
	"res://models/props/icecream_car/model.tscn",
	"res://models/props/bike/model.tscn",
	"res://models/props/dumptruck/model.tscn"
]
var ride_offset := 0.0


static func choose(passenger: bool, distance: float, stage: int, route: int) -> String:
	var slot := posmod(roundi(distance / 30.0) + stage * 7 + route * 3, 4)
	if passenger:
		return "bike" if slot == 0 else ""
	return "icecream_car" if slot % 2 == 0 else "dumptruck"


static func attach(motor: Node3D) -> void:
	if motor.road.closed_loop:
		return
	var id := choose(motor.get_meta("parked_car", false), motor.distance, motor.road.stage, motor.road.route_node)
	if id.is_empty():
		return
	var definition: Resource = Catalog.find("props", id)
	var source: Node3D = motor.visual
	var replacement := load("res://scripts/vehicles/tour_traffic_appearance.gd").new() as Node3D
	replacement.set_meta("traffic_model", id)
	replacement.set_meta("traffic_converted", true)
	replacement.add_child((Pool.fetch(definition.scene_path) as PackedScene).instantiate())
	source.get_parent().add_child(replacement)
	replacement.global_transform = source.global_transform.orthonormalized()
	var size: Vector3 = definition.base_size * Vector3(.9, .85, .96)
	motor.contact_shape.shape.size = size
	motor.contact_shape.position.y = size.y * .5 - motor.SUPPORT_HEIGHT
	motor.cruise_speed = 16 if id == "bike" else (13 if id == "icecream_car" else 11)
	motor.visual = replacement
	source.visible = false
	source.free()
