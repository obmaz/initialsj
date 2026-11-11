extends Node3D
# Solid landmarks can be viewed from any angle, including beside the lake.
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const PLACEMENTS := [
	[0.075, "torii", 1.0, 6.5],
	[0.205, "bridge", -1.0, 4.0],
	[0.32, "pagoda", 1.0, 14.0],
	[0.44, "pagoda", 1.0, 11.0],
	[0.66, "teahouse", 1.0, 8.0],
	[0.84, "torii", 1.0, 5.0]
]
var scenery: Node3D
var positions: Array[Vector3] = []
var widths: Array[float] = []
var landmark_distances: Array[float] = []
var models: Node3D


func _ready() -> void:
	var road: Node3D = scenery.track
	var placements: Array[Dictionary] = []
	for spec in PLACEMENTS:
		var d: float = road.length * spec[0]
		if road.on_bridge(d):
			continue
		var kind: String = spec[1]
		var side: float = spec[2]
		var scale: float = spec[3] / Props.model(kind).get_aabb().size.y
		var radius: float = Props.radius(kind) * scale
		var lane: float = side * (road.half_width(d) + road.rail_setback(d, side) + 4 + radius)
		var p: Vector3 = road.roadside_point(d, lane)
		var closest: float = road.curve.get_closest_offset(p)
		var center: Vector3 = road.point(closest)
		if (
			Vector2(p.x - center.x, p.z - center.z).length() - radius
			< road.half_width(closest) + road.rail_setback(closest, side) + 1.5
		):
			continue
		if side < 0:
			p.y = road.point(d).y - 2.0
		positions.append(p)
		widths.append(radius * 2)
		landmark_distances.append(d)
		placements.append({"position": p, "yaw": road.heading(d) + PI / 2, "scale": scale, "kind": kind})
	models = Props.new()
	models.name = "FujiLandmarks3D"
	models.configure("fuji", placements)
	add_child(models)
