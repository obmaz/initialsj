extends RefCounted
# Shared by the player and CPU cars. Ballistic motion uses world height so an
# ascending road can catch the car before the nominal flat-road landing time.
const GRAVITY := 27.0
const MIN_TRICK_LIFT := 6.2
const MAX_TRICK_LIFT := 7.2
var active := false
var trick := false
var height := 0.0
var world_y := 0.0
var velocity := 0.0
var landing_flash := 0.0
var landing_strength := 0.0
var launches := 0
var landings := 0
var consumed := {}
func reset() -> void:
	active = false
	trick = false
	height = 0
	world_y = 0
	velocity = 0
	landing_flash = 0
	landing_strength = 0
	launches = 0
	landings = 0
	consumed.clear()
static func ramp_height(section: Node3D, at: Vector2) -> float:
	var d := fposmod(at.y,section.length) if section.closed_loop else at.y
	for f in section.features:
		if f.kind != "ramp" or absf(at.x-f.lane) > f.width*0.5+0.7: continue
		var t: float = (d-(f.distance-f.length*0.5))/f.length
		if t >= 0 and t <= 1: return f.height*t
	return 0
static func launch_velocity(section: Node3D, feature: Dictionary, edge: float, lane: float, speed: float) -> float:
	# Carry the actual road grade into flight. A downhill launch must start
	# descending with that road instead of hovering while the ground falls away.
	var probe := clampf(float(feature.length)*0.25,1.0,4.0)
	var grade: float = (section.point(edge+probe,lane).y-section.point(edge-probe,lane).y)/(probe*2)
	var ramp_lift := maxf(0,speed)*float(feature.get("height",0.0))/maxf(1.0,float(feature.length))
	var trick_lift := clampf(ramp_lift+3.0,MIN_TRICK_LIFT,MAX_TRICK_LIFT)
	# A tall jump needs speed and sends the car much higher.
	if feature.get("big",false): trick_lift = clampf(ramp_lift+6.0,10.0,15.0)
	return speed*grade+trick_lift

func flight(delta: float, ground_y: float) -> bool:
	world_y += velocity*delta-0.5*GRAVITY*delta*delta
	velocity -= GRAVITY*delta
	height = maxf(0,world_y-ground_y)
	if world_y > ground_y: return false
	active = false
	landing_strength = clampf(absf(velocity)/10,0.25,1)
	velocity = 0
	height = 0
	world_y = ground_y
	landing_flash = 0.65
	landings += 1
	return true
func advance(section: Node3D, from: Vector2, to: Vector2, speed: float, delta: float) -> Array[String]:
	var events: Array[String] = []
	landing_flash = maxf(0,landing_flash-delta)
	var ground_y: float = section.point(to.y,to.x).y
	if active:
		if flight(delta,ground_y): events.append("land" if trick else "settle")
		return events
	height = ramp_height(section,to)
	world_y = ground_y+height
	if to.y <= from.y: return events
	var first := int(floor(from.y/section.length)) if section.closed_loop else 0
	var last := int(floor(to.y/section.length)) if section.closed_loop else 0
	for cycle in range(first,last+1):
		for f in section.features:
			if f.kind != "ramp" and f.kind != "crest": continue
			var edge: float = f.distance+f.length*0.5+(cycle*section.length if section.closed_loop else 0)
			if from.y >= edge or to.y < edge: continue
			var t := (edge-from.y)/(to.y-from.y)
			var lateral := lerpf(from.x,to.x,t)
			if absf(lateral-f.lane) > f.width*0.5+0.7: continue
			var key: String = f.id+":"+str(cycle)
			if consumed.has(key): continue
			consumed[key] = true
			active = true
			world_y = section.point(edge,lateral).y+float(f.get("height",0.0))
			trick = speed >= 20
			velocity = launch_velocity(section,f,edge,lateral,speed) if trick else 0.0
			if trick: launches += 1
			events.append("launch" if trick else "drop")
			if flight(delta*(1-t),ground_y): events.append("land" if trick else "settle")
			return events
	return events
