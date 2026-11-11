@tool
extends Node


# 편집기에서도 GLB 형상과 조립 씬의 배치를 함께 확인한다.
func _ready() -> void:
	if Engine.is_editor_hint():
		preload("res://scripts/rendering/world_assets.gd").geometry(get_parent())
