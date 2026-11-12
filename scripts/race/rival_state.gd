extends RefCounted
# 상대 차량 한 대의 경기 상태. 주행·접촉 판단은 world_race.gd의 실제 차체가 담당한다.
const SurfaceState = preload("res://scripts/track/road_surface_state.gd")
const AirState = preload("res://scripts/physics/air_state.gd")
const DECISION_INTERVAL := .24
const FAR_PLAN_INTERVAL := .12
var car: Node3D
var id := 0
var active := false
var distance := 0.0
var speed := 0.0
var pace := 0.0
var lane := 0.0
var target_lane := 0.0
# 다음 차선 판단까지 남은 시간.
var decision := 0.0
# 먼 차량도 이동과 타이머는 매 틱 진행하고 속도 계획만 짧게 재사용한다.
var plan_time := 0.0
var curve_limit := INF
var traffic_limit := INF
var boost_curve := 0.0
var surface: RefCounted
var air: RefCounted
var boosting := false
var drifting := false
# 막혔을 때의 짧은 후진: 정지 누적 시간, 남은 후진 시간, 재시도 대기, 후진 중 조향.
var world_stuck := 0.0
var world_reverse := 0.0
var world_reverse_cooldown := 0.0
var world_reverse_axis := 0.0
# 먼 차량이 건너뛴 물리 시간과 표시 애니메이션 실행 여부.
var lod_time := 0.0
var visual_running := true
var vehicle_index := 0
var specification: Dictionary = {}
var style: Dictionary = {}
var boost_energy := 0.0
var boost_charges := 0
var boost_left := 0.0
var boost_cooldown := 0.0
var boost_lap := 0
var corner_memory := 0.0
var nitro_active := false
var boost_cell := false


func _init(visual: Node3D = null) -> void:
	car = visual


# 16대 출발·복구에서도 모든 상대의 비싼 차선 판단이 같은 틱에 몰리지 않게 한다.
static func decision_phase(index: int) -> float:
	return float(posmod(index, 15)) * DECISION_INTERVAL / 15.0


# 경기 시작 전의 기본 배치. 모드별 배치는 race.gd가 이어서 덮어쓴다.
func reset(index: int) -> void:
	id = index
	preload("res://scripts/race/rival_driving.gd").reset(self, index)
	active = index < 8
	distance = 150.0 + index * 57
	speed = 32.0 + (index % 5) * 4
	pace = speed
	lane = [-6.0, -2.0, 2.0, 6.0][index % 4]
	target_lane = lane
	decision = decision_phase(index)
	lod_time = 0
	surface = SurfaceState.new()
	air = AirState.new()
	boosting = false
	drifting = false
