extends Node3D
# 바다·절벽·마을이 실제 도로 높이에 이어지는 해안 지형입니다.
# 먼 산은 낮은 다각형 수의 입체 섬이며 가로수·상점은 기존 원본 메시를 배치합니다.
const Profile = preload("res://scripts/track/riviera_profile.gd")
var track: Node3D
var theme := "riviera"
var tree_batches: Array[MultiMeshInstance3D] = []
var tree_positions: Array[Vector3] = []
var water: MeshInstance3D
var rock_arches: Node3D
var landmarks: Node3D


func make_sky() -> Sky:
	return preload("res://scripts/environment/track_background.gd").create(
		"res://assets/environment/track-riviera-panorama.png"
	)


func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d, lane)
	# 차선 안의 지형도 뱅킹을 따라 낮춰야 안쪽 차선을 흙과 충돌면이 덮지 않습니다.
	var road_y: float = track.point(d, clampf(lane, -17, 17)).y
	if lane < 0:
		var reach := absf(lane)
		var coast := lerpf(road_y - 0.28, -2.8, smoothstep(17, 110, reach))
		coast = lerpf(coast, -5.0, smoothstep(170, 230, reach))
		# 협곡으로 들어갈 때만 반도가 천천히 솟고, 먼 해안은 수면 아래로 돌아간다.
		var peninsula := lerpf(road_y - .28, -4.0, smoothstep(180, 410, reach))
		p.y = lerpf(coast, peninsula, Profile.canyon_amount(d) * smoothstep(22, 68, reach))
	else:
		p.y = road_y - 0.28 + 26 * smoothstep(20, 115, lane) * (0.7 + 0.3 * sin(d * 0.004))
	return p


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
