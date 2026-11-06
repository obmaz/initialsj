extends SceneTree
const Report = preload("res://tests/report.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	race.choose_mode("track",1)
	var report := []
	for index in range(3):
		race.open_garage()
		race.select_vehicle(index)
		race.restart()
		race.state = "racing"
		var peak := 0.0
		var target_lane := 0.0
		for frame in range(24000):
			if frame%20 == 0:
				var best := INF
				for candidate in race.track.lane_centers(race.distance):
					var cost: float = absf(candidate-race.lane)*0.1+race.Features.lane_cost(race.track.active,race.distance,candidate)
					for other in race.rivals:
						if not other.active: continue
						var gap: float = race.relative_gap(other.distance,race.distance)
						if absf(candidate-other.lane) < 3 and gap > -8 and gap < 55: cost += 55-gap
						if absf(gap) < 8 and other.lane > minf(candidate,race.lane)-2.5 and other.lane < maxf(candidate,race.lane)+2.5: cost += 150
					if cost < best: best = cost; target_lane = candidate
			var curve: float = race.track.curvature(race.distance)
			var allowed: float = race.vehicle.overdrive_speed
			for look in [0.0,25.0,55.0,90.0,135.0]:
				var safe: float = sqrt((race.vehicle.drift_grip+race.track.active.banking_grip(race.distance+look))*race.surface.grip_factor/maxf(absf(race.track.curvature(race.distance+look)),0.0001))
				allowed = minf(allowed,sqrt(safe*safe+2*36*look))
			var brake: bool = race.speed > allowed+0.7
			var slide: bool = absf(curve)*race.speed*race.speed > race.vehicle.grip*0.9 and race.speed > 28
			var grip: float = ((race.vehicle.drift_grip if race.drifting else race.vehicle.grip)+race.track.active.banking_grip(race.distance))*race.surface.grip_factor
			var demand: float = absf(curve)*race.speed*race.speed
			var excess := maxf(0,demand-grip)
			var authority := clampf(1-excess/(grip*2),0.38,1)
			var outward := signf(curve)*(demand*0.055+excess*1.6)
			var desired: float = clampf((target_lane-race.lane)*2-race.lane_velocity*0.45,-8,8)
			var lateral: float = race.vehicle.drift_steer_speed if race.drifting else race.vehicle.steer_speed
			var sensitivity := lerpf(1,0.86,smoothstep(35,85,race.speed))
			var axis := clampf((desired-outward)/(lateral*authority*sensitivity*maxf(0.2,minf(race.speed/20,1))),-1,1)
			axis = signf(axis)*pow(absf(axis),1.0/1.22)
			if slide and not race.drifting and absf(axis) < 0.25: axis = -signf(curve)*0.35
			var nitro: bool = not slide and not brake and allowed > race.vehicle.max_speed+5 and race.nitro > (2 if race.nitro_active else 20)
			if race.vehicle.mode == "charges": nitro = not slide and not brake and allowed > race.vehicle.max_speed+5 and race.nitro_burst_left <= 0 and race.nitro_cooldown <= 0 and race.nitro_charges > 0
			var drift_tap: bool = (slide and not race.drifting) or (race.drifting and demand < race.vehicle.grip*race.surface.grip_factor*0.65)
			race.step(1.0/60,axis,drift_tap,true,brake,nitro,nitro and race.vehicle.mode == "hybrid" and race.nitro_burst_left <= 0 and race.nitro_cooldown <= 0)
			peak = maxf(peak,race.speed)
			if race.state == "finished": break
		var entry := {"vehicle":race.vehicle.id,"state":race.state,"laps":race.laps_completed,"seconds":snappedf(race.elapsed,0.01),"position":race.race_position(),"peak_kmh":snappedf(peak*3.6,0.1),"walls":race.wall_hits,"contacts":race.traffic_hits,"boost_pads":race.surface.boosts_hit,"puddles":race.surface.puddles_hit}
		print(JSON.stringify(entry))
		report.append(entry)
		if race.state != "finished" or race.laps_completed != 3 or race.elapsed > 300:
			push_error("Every vehicle must be able to complete Suncoast's three-lap race")
			failures += 1
		for other in race.rivals:
			if other.respawns != 0:
				push_error("Circuit opponents must never recycle or teleport")
				failures += 1
		await process_frame
	FileAccess.open(Report.path("speedway-drive-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"vehicles":report,"failures":failures},"\t")+"\n")
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
