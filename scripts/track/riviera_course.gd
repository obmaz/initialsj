extends RefCounted
# 도로의 원본 형상과 주행 곡선은 같은 코스 팩에서 읽는다.


static func build(section: Node3D) -> void:
	section.closed_loop = true
	section.course_id = 3
	preload("res://scripts/rendering/world_assets.gd").profile(section)
