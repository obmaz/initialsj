extends RefCounted
# Numbers both driving controllers share, so Fuji (real 3D physics) and the road-space Tour and
# Suncoast controller feel alike. Change a value here and both follow.

# Ordinary steering never exceeds this multiple of the tyre grip in lateral acceleration.
const LATERAL_GRIP_FACTOR := 1.8
# How hard a steering input past the grip limit scrubs speed (understeer).
const UNDERSTEER_SCRUB := 0.5
# A rail hit below the launch speed: speed kept along the rail (soft hit .. hard hit), the small
# push back off the rail and how long the nose takes to turn parallel to the road.
const GLIDE_KEEP_SOFT := 0.97
const GLIDE_KEEP_HARD := 0.84
const GLIDE_REBOUND := 0.10
const GLIDE_REBOUND_MAX := 3.0
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
