extends Node3D
# MIDNIGHT HARBOR scenery: a dark container yard with lit warehouses, cranes, street lamps with
# light pools on the road, neon drift gates and a star sky. All real 3D boxes in a handful of
# MultiMesh batches (no per-lamp lights), so it stays cheap on phones.
const GROUND_Y := 3.3
const EDGE_EXTRA := 1.3
var theme := "night"
var track: Node3D
var tree_positions: Array[Vector3] = []
var batches: Array[MultiMeshInstance3D] = []
var rng := RandomNumberGenerator.new()
var drift_gates: Array[float] = []


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/harbor-panorama.png", .12
	)


func set_ground_enabled(_enabled: bool) -> void:
	pass


# Dark yard around the road: it follows the road height near the edge and falls to the harbour
# ground level within about 30 m, so the road reads as raised on a low embankment.
func terrain_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(distance, lane)
	var road_y: float = track.ground_height(distance) - 0.25
	var edge: float = track.half_width(distance) + track.rail_setback(distance, signf(lane)) + EDGE_EXTRA
	p.y = lerpf(road_y, GROUND_Y, smoothstep(0.0, 30.0, absf(lane) - edge))
	return p


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func clear_of_road(d: float, lane: float, margin: float) -> bool:
	# Props stay away from every other stretch of the circuit, not just their own.
	var candidate_point: Vector3 = track.point(d, lane)
	var nearest_distance: float = track.curve.get_closest_offset(candidate_point)
	var nearest_road_point: Vector3 = track.point(nearest_distance)
	var reach: float = track.half_width(nearest_distance) + track.rail_setback(nearest_distance, 1.0) + margin
	return Vector2(candidate_point.x - nearest_road_point.x, candidate_point.z - nearest_road_point.z).length() >= reach


func cargo_material() -> Material:
	return preload("res://scripts/environment/regional_props_3d.gd").material_for("containers")


func cargo_mesh(brand: int) -> ArrayMesh:
	return get_node("Containers" + str(posmod(brand, 3))).multimesh.mesh
