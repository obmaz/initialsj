extends Node3D
var scenery: Node3D
var swing: Node3D
var elapsed := 0.0
var carousel: Node3D
var coaster_samples := 0


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not scenery.is_processing():
		return
	elapsed += delta
	if swing != null:
		swing.rotation.z = sin(elapsed * .72) * .85
	if carousel != null:
		carousel.rotation.y = elapsed * .18
