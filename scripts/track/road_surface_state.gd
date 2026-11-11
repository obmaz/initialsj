extends RefCounted
const Features = preload("res://scripts/track/road_features.gd")
const PAD_DURATION := 1.2
const WET_DURATION := 1.4
const MUD_DRAG_TIME := 0.45
var pad_time := 0.0
var lane_active := false
var wet_time := 0.0
var pad_flash := 0.0
var water_flash := 0.0
var mud_time := 0.0
var mud_flash := 0.0
var truck_flash := 0.0
var truck_lane := 0.0
var boosts_hit := 0
var puddles_hit := 0
var consumed := {}
var touching := {}
var wetness: float:
	get: return clampf(wet_time/WET_DURATION,0,1)
var grip_factor: float:
	get: return lerpf(1.0,0.55,wetness)
var lateral_factor: float:
	get: return lerpf(1.0,0.30,wetness)

func reset() -> void:
	pad_time = 0
	lane_active = false
	wet_time = 0
	pad_flash = 0
	water_flash = 0
	mud_time = 0
	mud_flash = 0
	truck_flash = 0
	boosts_hit = 0
	puddles_hit = 0
	consumed.clear()
	touching.clear()

func cancel_boost() -> void:
	pad_time = 0
	lane_active = false
	pad_flash = 0

func tick(delta: float, brake: bool = false, impact: float = 0) -> void:
	pad_time = maxf(0,pad_time-delta)
	wet_time = maxf(0,wet_time-delta)
	pad_flash = maxf(0,pad_flash-delta)
	water_flash = maxf(0,water_flash-delta)
	mud_time = maxf(0,mud_time-delta)
	mud_flash = maxf(0,mud_flash-delta)
	truck_flash = maxf(0,truck_flash-delta)
	if brake or impact >= 0.15: cancel_boost()

func update_lane(section: Node3D, at: Vector2, speed: float, brake: bool = false, impact: float = 0, grounded: bool = true) -> void:
	var was := lane_active
	lane_active = false
	if not grounded or brake or impact >= 0.15 or speed <= 5: return
	var d := fposmod(at.y,section.length) if section.closed_loop else at.y
	for feature in section.features:
		if feature.kind != "boost_lane": continue
		var gap: float = wrapf(d-feature.distance,-section.length*0.5,section.length*0.5) if section.closed_loop else d-feature.distance
		if absf(gap) <= feature.length*0.5 and absf(at.x-feature.lane) <= feature.width*0.5-0.4:
			lane_active = true
			if not was: pad_flash = maxf(pad_flash,0.65)
			break

func contact(section: Node3D, from: Vector2, to: Vector2, speed: float, brake: bool = false, impact: float = 0) -> Array[String]:
	update_lane(section,to,speed,brake,impact)
	var events: Array[String] = []
	var current := {}
	var first_cycle := int(floor(minf(from.y,to.y)/section.length)) if section.closed_loop else 0
	var last_cycle := int(floor(maxf(from.y,to.y)/section.length)) if section.closed_loop else 0
	for cycle in range(first_cycle,last_cycle+1):
		for feature in section.features:
			var center: float = feature.distance+(cycle*section.length if section.closed_loop else 0)
			if not Features.swept_hit(feature,from,to,center): continue
			var key: String = feature.id+":"+str(cycle)
			current[key] = true
			if feature.kind == "water":
				wet_time = WET_DURATION
				if not touching.has(key):
					puddles_hit += 1
					water_flash = 1.2
					events.append("water")
			elif feature.kind == "mud":
				mud_time = MUD_DRAG_TIME
				if not touching.has(key):
					mud_flash = 1.2
					events.append("mud")
			elif feature.kind == "truck":
				if not touching.has(key):
					truck_lane = float(feature.lane)
					truck_flash = 1.2
					events.append("truck")
			elif feature.kind == "boost" and speed > 5 and not brake and impact < 0.15 and not consumed.has(key):
				consumed[key] = true
				pad_time = float(feature.get("duration",PAD_DURATION))
				pad_flash = 1.1
				boosts_hit += 1
				events.append("boost")
	touching = current
	return events
