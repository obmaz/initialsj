extends Node3D
# 투어와 서킷이 공유하는 원본 입체 구조물입니다. 도로 안에는 장식 충돌체를 놓지 않습니다.
const Ads = preload("res://scripts/environment/advertisement_library.gd")
var track: Node3D
var bridge_span := Vector2.ZERO
var canyon_spans: Array[Vector2] = []
var batches: Array[MultiMeshInstance3D] = []
var billboard_manifest: Array[Dictionary] = []
var tower_distances: Array[float] = []
var bridge_clearance := 68.0
var ad_size := Vector2(20, 8.75)
const AD_METRE_SCALE := 1.25
var texture_regions: Array[Vector3] = []
var advertisement_spans: Array[Vector2] = []
var ad_spacing := 135.0


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func cable_height(d: float) -> float:
	var a := bridge_span.x + 95
	var b := bridge_span.y - 95
	if d < a:
		return lerpf(4, 90, (d - bridge_span.x) / (a - bridge_span.x))
	if d > b:
		return lerpf(90, 4, (d - b) / (bridge_span.y - b))
	return 22 + 68 * pow((d - (a + b) * 0.5) / ((b - a) * 0.5), 2)


func advertisement_material(index: int) -> Material:
	return Ads.material(index)
