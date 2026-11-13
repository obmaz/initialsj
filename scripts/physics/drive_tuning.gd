extends RefCounted
# 투어와 모든 트랙의 실제 차체가 공유하는 주행·충돌 조정값.

# 일반 조향의 횡가속도를 타이어 접지력의 이 배수 이하로 제한한다.
const LATERAL_GRIP_FACTOR := 1.8
# 접지력 한계를 넘는 조향에서 속도를 줄이는 정도.
const UNDERSTEER_SCRUB := 0.5
# 비행 임계값 아래의 접촉: 전진 속도를 보존하며 노면을 따라 옆으로 짧게 튕긴다.
const GLIDE_KEEP_SOFT := 0.86
const GLIDE_KEEP_HARD := 0.64
const GLIDE_REBOUND := 0.22
const GLIDE_REBOUND_MAX := 3.6
const REALIGN_TIME := 0.9
# 이 속도 이상의 레일 접촉에서 불꽃·진동을 표시한다.
const SCRAPE_SPEED := 14.0
# 충돌 비행 중 차체의 앞부분을 이동 방향으로 돌리는 각속도(rad/s).
const FLIGHT_TURN_RATE := 3.5


# 접촉 강도에 따라 보존할 진행 속도의 비율.
static func glide_keep(hardness: float) -> float:
	return lerpf(GLIDE_KEEP_SOFT, GLIDE_KEEP_HARD, clampf(hardness, 0, 1))


# 명목 점프 설계의 중력27과 모든 모드가 공유하는 실제 물리의 중력24를 구분한다.
const WORLD_GRAVITY := 24.0
const DESIGN_GRAVITY := 27.0
const LAUNCH_AWAY_SCALE := 0.85


static func world_launch_up(road_space_up: float) -> float:
	# 레일 형상과 차체 피치로 생기는 추가 상승을 0.9배 보정한다.
	return road_space_up * sqrt(WORLD_GRAVITY / DESIGN_GRAVITY) * 0.9
