extends RefCounted
# 투어와 모든 트랙의 실제 차체가 공유하는 주행·충돌 조정값.

# Ordinary steering never exceeds this multiple of the tyre grip in lateral acceleration.
const LATERAL_GRIP_FACTOR := 1.8
# How hard a steering input past the grip limit scrubs speed (understeer).
const UNDERSTEER_SCRUB := 0.5
# 비행 임계값 아래의 접촉: 전진 속도를 보존하며 노면을 따라 옆으로 짧게 튕긴다.
const GLIDE_KEEP_SOFT := 0.97
const GLIDE_KEEP_HARD := 0.84
const GLIDE_REBOUND := 0.22
const GLIDE_REBOUND_MAX := 3.6
const REALIGN_TIME := 0.9
# Scraping a rail above this speed throws sparks and rumbles.
const SCRAPE_SPEED := 14.0
# Within this distance of the road edge the kerb shakes the camera.
const KERB_MARGIN := 1.1
# A launching hit pushes sideways with this share of the closing speed (road-space), and the
# car turns its nose back toward the road direction at this rate (rad/s, Fuji flight).
const LAUNCH_PUSH := 0.63
const FLIGHT_TURN_RATE := 3.5

# Speed kept after a glancing rail hit: harder hits cost more, same curve in both controllers.
static func glide_keep(hardness: float) -> float:
	return lerpf(GLIDE_KEEP_SOFT,GLIDE_KEEP_HARD,clampf(hardness,0,1))

# A launching rail hit should look the same in both controllers. The Tour jumps under gravity 27
# and Fuji under 24, so Fuji launches slower by sqrt(24/27) to reach the same height, and its
# push off the rail is scaled to match the Tour's lane bounce.
const FUJI_GRAVITY := 24.0
const TOUR_GRAVITY := 27.0
const LAUNCH_AWAY_SCALE := 0.85
static func world_launch_up(road_space_up: float) -> float:
	# 0.9 absorbs the extra lift the real body gets from rail geometry and its own pitch.
	return road_space_up*sqrt(FUJI_GRAVITY/TOUR_GRAVITY)*0.9

