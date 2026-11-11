extends Node3D
var track: Node3D
var theme := "gorge"
var tree_positions: Array[Vector3] = []
var landmarks: Node3D


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/gorge-sunset-panorama.png"
	)


func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d, lane)
	var road_y: float = track.point(d, clampf(lane, -17, 17)).y - 0.3
	var bay := (
		smoothstep(track.bridge_span.x - 25, track.bridge_span.x + 45, d)
		* (1 - smoothstep(track.bridge_span.y - 55, track.bridge_span.y + 20, d))
	)
	p.y = lerpf(road_y, 1.0, bay)
	return p


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
