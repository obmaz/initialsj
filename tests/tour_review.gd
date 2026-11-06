extends SceneTree
const Report = preload("res://tests/report.gd")
var failures := 0
var report := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	race.set_physics_process(false)
	race.save_records = false
	for strategy in ["gas_only","brake_and_drift_left","brake_and_drift_right","brake_and_drift_mixed","veltrix_right","ironvale_right"]:
		race.open_garage()
		race.select_vehicle(1 if strategy.begins_with("veltrix") else (2 if strategy.begins_with("ironvale") else 0))
		race.restart()
		race.state = "racing"
		var desired_lane := -2.0
		var checkpoint := 0
		var peak_speed := 0.0
		var drift_seconds := 0.0
		for frame in range(36000):
			var curve: float = race.track.curvature(race.distance)
			var brake := false
			var axis := 0.0
			var slide := false
			var nitro_input := false
			if strategy != "gas_only":
				if frame % 18 == 0:
					var best := INF
					for candidate in race.track.lane_centers(race.distance):
						var cost: float = absf(candidate-race.lane)*0.1+race.Features.lane_cost(race.track.active,race.distance,candidate)
						for r in race.rivals:
							if not r.active or r.detached != null: continue
							var gap: float = r.distance-race.distance
							if absf(candidate-r.lane) < 3 and gap > -8 and gap < 65: cost += 65-gap
							if absf(gap) < 8 and r.lane > minf(candidate,race.lane)-2.5 and r.lane < maxf(candidate,race.lane)+2.5: cost += 150
						if cost < best:
							best = cost
							desired_lane = candidate
				if race.stage_index < 4 and race.distance > race.track.length-220:
					var choose_right: bool = strategy.ends_with("right") or (strategy.ends_with("mixed") and race.stage_index % 2 == 1)
					desired_lane = 4.0 if choose_right else -4.0
				var allowed: float = race.vehicle.overdrive_speed
				for look in [0.0,25.0,55.0,90.0,135.0]:
					var k: float = absf(race.track.curvature(race.distance+look))
					var corner_speed := sqrt(race.vehicle.drift_grip*race.surface.grip_factor/maxf(k,0.0001))
					allowed = minf(allowed,sqrt(corner_speed*corner_speed+2*36*look))
				brake = race.speed > allowed+0.7
				slide = absf(curve)*race.speed*race.speed > race.vehicle.grip*0.9 and race.speed > 28
				var grip: float = (race.vehicle.drift_grip if race.drifting else race.vehicle.grip)*race.surface.grip_factor
				var demand: float = absf(curve)*race.speed*race.speed
				var excess := maxf(0,demand-grip)
				var authority := clampf(1-excess/(grip*2),0.38,1)
				authority *= lerpf(1,0.72,smoothstep(0.45,1.2,demand/maxf(grip,1))*smoothstep(35,70,race.speed))
				var outward := signf(curve)*(demand*0.055+excess*1.6)
				var desired: float = clampf((desired_lane-race.lane)*2.1-race.lane_velocity*0.45,-8,8)
				axis = clampf((desired-outward)/((race.vehicle.drift_steer_speed if race.drifting else race.vehicle.steer_speed)*authority*maxf(0.2,minf(race.speed/20,1))),-1,1)
				if slide and not race.drifting and absf(axis) < 0.25: axis = -signf(curve)*0.35
				nitro_input = not slide and not brake and allowed > race.vehicle.max_speed+5 and race.nitro > (2 if race.nitro_active else 20)
				if race.vehicle.mode == "charges": nitro_input = not slide and not brake and allowed > 95 and race.nitro_burst_left <= 0 and race.nitro_cooldown <= 0 and race.nitro_charges > 0
			var drift_tap: bool = (slide and not race.drifting) or (strategy != "gas_only" and race.drifting and absf(curve)*race.speed*race.speed < race.vehicle.grip*race.surface.grip_factor*0.65)
			race.step(1.0/60,axis,drift_tap,true,brake,nitro_input,nitro_input and race.vehicle.mode == "hybrid" and race.nitro_burst_left <= 0 and race.nitro_cooldown <= 0)
			peak_speed = maxf(peak_speed,race.speed)
			if race.drifting: drift_seconds += 1.0/60
			if race.checkpoints != checkpoint:
				checkpoint = race.checkpoints
				await process_frame
			if race.state in ["finished","failed"]: break
		report[strategy] = {"state":race.state,"stage":race.stage_index+1,"seconds":snappedf(race.elapsed,0.01),"remaining":snappedf(race.time_left,0.01),"distance_m":snappedf(race.journey_distance,1),"peak_kmh":snappedf(peak_speed*3.6,0.1),"wall_hits":race.wall_hits,"traffic_hits":race.traffic_hits,"drift_seconds":snappedf(drift_seconds,0.1),"boost_pads":race.surface.boosts_hit,"puddles":race.surface.puddles_hit,"nitro_seconds":snappedf(race.nitro_seconds,0.1),"route":race.track.history.duplicate()}
		print(strategy," ",JSON.stringify(report[strategy]))
		await process_frame
	if report.gas_only.state != "failed":
		push_error("Holding gas without cornering must not clear the tour")
		failures += 1
	for strategy in ["brake_and_drift_left","brake_and_drift_right","brake_and_drift_mixed","veltrix_right","ironvale_right"]:
		if report[strategy].state != "finished" or report[strategy].peak_kmh < 270:
			push_error("Skilled braking and drifting must finish the tour while retaining high speed: " + strategy)
			failures += 1
	report.failures = failures
	var output := FileAccess.open(Report.path("tour-metrics.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	race.queue_free()
	await process_frame
	quit(1 if failures else 0)
