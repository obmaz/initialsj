extends RefCounted
# Arcade tyre scrub in metres/second². Inputs describe actual motion/load;
# steering input alone, stationary wheels and straight visual drift add no drag.
static func loss_rate(speed: float, lateral_accel: float, grip: float, slip: float, drifting: bool) -> float:
	speed = absf(speed)
	lateral_accel = absf(lateral_accel)
	if speed < 3.0 or lateral_accel < 0.25: return 0.0
	var load := lateral_accel/maxf(grip,3.0)
	var overload := clampf(load-0.55,0,2.5)
	var scrub := lateral_accel*(0.08+0.11*overload)
	scrub += maxf(speed-5.0,0)*sin(clampf(absf(slip),0,1.2))*0.07*minf(load,1.5)
	return scrub*(0.64 if drifting else 1.0)

static func engine_factor(speed: float, cap: float, lateral_accel: float, grip: float) -> float:
	# Loaded tyres consume the small amount of engine force still available
	# near cruise. Straight acceleration and low-speed launches retain full force.
	# An expired boost must retain the caller's engine braking toward cruise.
	if absf(speed) > maxf(0,cap): return 1.0
	var activity := smoothstep(0.03,0.15,absf(lateral_accel)/maxf(grip,3.0))
	var available := clampf((maxf(0,cap)-absf(speed))/20.0,0,1)
	return lerpf(1.0,available,activity)
