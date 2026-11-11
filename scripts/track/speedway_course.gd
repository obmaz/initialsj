extends RefCounted
# 도로의 원본 형상과 주행 곡선은 같은 코스 팩에서 읽는다.


static func offset(section: Node3D, index: int) -> float:
	return section.get_meta("speedway_offsets")[index]


static func infield_amount(section: Node3D, distance: float) -> float:
	var d := fposmod(distance, section.length)
	return (
		smoothstep(offset(section, 10), offset(section, 12), d)
		* (1 - smoothstep(offset(section, 25), offset(section, 28), d))
	)


static func build(section: Node3D) -> void:
	section.closed_loop = true
	section.course_id = 1
	preload("res://scripts/rendering/world_assets.gd").profile(section)
