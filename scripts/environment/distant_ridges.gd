extends Node3D
# Mountain horizons use generated cutouts; urban horizons use solid low-detail buildings.
const ATLAS_PATH = "res://assets/environment/horizon-ridges.png"
const URBAN_THEMES := {"city": 0, "seoul": 1, "ruins": 2, "neon": 3}
const REGIONS := [
	Vector4(0.02029312, 0.20067644, 0.46392334, 0.17361894),
	Vector4(0.51578354, 0.24351747, 0.46843292, 0.13190530),
	Vector4(0.01127396, 0.71476888, 0.47688839, 0.13077790),
	Vector4(0.50901917, 0.67756483, 0.48196167, 0.16572717)
]
const THEMES := {"hawaii": 0, "jeju": 1, "jungle": 1, "pyramid": 2, "canyon": 2, "snow": 3}
var scenery: Node3D
var positions: Array[Vector3] = []
var widths: Array[float] = []
var sprite_batch: MultiMeshInstance3D


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
