extends Node3D
# 실제 노면과 일치하는 경기장 지형·콘크리트 방호벽·관중석·광고 구역.
const BASE_HEIGHT := 6.5
const BERM_REACH := 45.0
const WALL_HEIGHT := 1.7
const AD_SPACING := 50.0
const STAND_COUNT := 16
const STAND_CENTER := 350.0
const STAND_GAP := 3.5
const WALL_AD_EDGES := [0., .1849, .3625, .5366, .7057, .8760, 1.]
var track: Node3D
var theme := "speedway"
var batches: Array[MultiMeshInstance3D] = []
var grandstand_anchors: Array[Transform3D] = []
var ad_regions: Array[Vector2] = []
var wall_ads: Array[Dictionary] = []


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/speedway-panorama.png"
	)


# 좁은 인필드 코너에서 지형 띠가 회전 중심을 넘어 뒤집히지 않게 한다.
func berm_reach(d: float) -> float:
	var edge: float = track.half_width(d) + 2
	return minf(BERM_REACH, maxf(8, .7 / maxf(.0001, absf(track.curvature(d))) - edge))


func ground_height(d: float, lane: float) -> float:
	var edge: float = track.half_width(d) + track.rail_setback(d, signf(lane)) + .65
	var platform: float = maxf(BASE_HEIGHT, track.point(d, signf(lane) * edge).y - .15)
	# 지형 메시와 같은 9개 구간 사이를 보간해 부지와 실제 지형의 높이를 맞춘다.
	var u := clampf((absf(lane) - edge) / berm_reach(d), 0, 1) * 9
	var first := floorf(u)
	var blend := lerpf(smoothstep(0, 9, first), smoothstep(0, 9, minf(9, first + 1)), u - first)
	return lerpf(platform, BASE_HEIGHT, blend)


func outer_ground_height(d: float, lane: float) -> float:
	return ground_height(d, absf(lane))


func inner_ground_height(d: float, lane: float) -> float:
	return ground_height(d, -absf(lane))


func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d, lane)
	p.y = ground_height(d, lane)
	return p


func distance_at_xz(p: Vector3) -> float:
	var d: float = track.curve.get_closest_offset(p)
	for iteration in range(4):
		var q: Vector3 = track.point(d)
		var tangent: Vector3 = (track.point(d + 1) - track.point(d - 1)) * .5
		var derivative := Vector2(tangent.x, tangent.z)
		var offset := Vector2(p.x - q.x, p.z - q.z)
		d = fposmod(d + clampf(offset.dot(derivative) / maxf(.01, derivative.length_squared()), -80, 80), track.length)
	return d


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func wall_point(d: float, height: float, offset: float = 0, side: float = 1) -> Vector3:
	# 인쇄면을 방호벽과 같은 4m 구간에 맞춰 곡선 안쪽으로 묻히는 깊이 충돌을 막는다.
	var step: float = track.length / ceili(track.length / 4)
	var cell := fposmod(d, track.length) / step
	var a := floorf(cell) * step
	var b := a + step
	var left: Vector3 = track.point(a, side * (track.half_width(a) + track.rail_setback(a, side) + offset))
	var right: Vector3 = track.point(b, side * (track.half_width(b) + track.rail_setback(b, side) + offset))
	return left.lerp(right, cell - floorf(cell)) + Vector3.UP * height


func set_shadow_quality(enabled: bool) -> void:
	for node in batches:
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
