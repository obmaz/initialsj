extends Node3D
# 도로 형상을 따르는 정글의 덩굴·흙덮개·두꺼운 암석 터널 입구.
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const Library = preload("res://scripts/track/route_library.gd")
const ROCK = "res://assets/environment/jungle-moss-stone.png"
var scenery: Node3D
var road: Node3D
var material: ShaderMaterial
var vine_count := 0
var roof_sections := 0
var hanging_clearance := INF


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func roof_point(d: float, u: float) -> Vector3:
	var width: float = road.half_width(d) + 23
	var left: Vector3 = scenery.terrain_point(d, -width)
	var right: Vector3 = scenery.terrain_point(d, width)
	var p: Vector3 = road.point(d, lerpf(-width, width, u))
	p.y = maxf(p.y + 10, lerpf(left.y, right.y, u) + 7 * sin(PI * u))
	return p
