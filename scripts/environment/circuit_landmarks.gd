extends Node3D
# Solid landmarks can be viewed from any angle, including beside the lake.
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
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
