extends RefCounted
# Reusable road traffic: lane planning, safe gaps, preview braking and off-screen recycling.
func initialize(rivals: Array[Dictionary]) -> void:
	for i in range(rivals.size()):
		var r: Dictionary = rivals[i]
		r.id = i
		r.active = i < 8
		r.respawns = 0
		r.distance = 150.0 + i * 57
		r.speed = 32.0 + (i % 5) * 4
		r.pace = float(r.speed)
		r.lane = [-6.0,-2.0,2.0,6.0][i % 4]
		r.target_lane = float(r.lane)
		r.decision = i * 0.07
		r.route_side = i % 2
		r.detached = null
		r.boosting = false
		r.visual_yaw = 0.0

func tick(race: Node3D, delta: float) -> void:
	var traffic: Array[Dictionary] = [{"distance":race.distance,"lane":race.lane,"speed":race.speed}]
	traffic.append_array(race.rivals)
	for r in race.rivals:
		if not r.active: continue
		if r.detached != null:
			if is_instance_valid(r.detached):
				r.distance += r.speed * delta
				if r.detached.point(r.distance,r.lane).distance_to(race.track.point(race.distance,race.lane)) < 450: continue
			recycle(race,r)
		if race.mode == "tour" and r.distance < race.distance - 65:
			recycle(race,r)
		var d: float = r.distance
		var edge: float = race.track.half_width(d)-0.2
		r.target_lane = clampf(r.target_lane,-edge,edge)
		r.decision -= delta
		if r.decision <= 0:
			r.decision = 0.24
			var best := INF
			var chosen: float = r.lane
			for candidate in race.track.lane_centers(d):
				var cost: float = absf(candidate-r.lane) * 0.35
				for other in traffic:
					if other == r or not other.get("active",true) or other.get("detached") != null: continue
					var gap: float = race.relative_gap(other.distance,d)
					if absf(other.lane-candidate) < 2.5 and gap > -12 and gap < 36:
						cost += (36-gap) * (1.0 if other.speed < r.speed+3 else 0.25)
					if absf(gap) < 8 and other.lane > minf(r.lane,candidate)-2.1 and other.lane < maxf(r.lane,candidate)+2.1: cost += 160
					if gap < 0 and gap > -45 and other.speed > r.speed+8 and absf(other.lane-candidate) < 2.5: cost += 70
				if cost < best:
					best = cost
					chosen = candidate
			r.target_lane = chosen
		r.lane = clampf(move_toward(float(r.lane),float(r.target_lane),delta*3.1),-edge,edge)
		r.visual_yaw = lerp_angle(r.visual_yaw,-clampf((r.target_lane-r.lane)/2,-1,1)*0.07,1-exp(-delta*6))
		var target: float = r.pace
		for look in [0.0,35.0,80.0,130.0]:
			var curve: float = absf(race.track.curvature(d+look))
			var safe := sqrt((race.vehicle.grip*1.2 if race.mode == "track" else 12.5) / maxf(curve,0.0001))
			target = minf(target,sqrt(safe * safe + 2 * 40 * look))
		for other in traffic:
			if other == r or not other.get("active",true) or other.get("detached") != null or absf(other.lane-r.lane) > 2.3: continue
			var gap: float = race.relative_gap(other.distance,d)
			if gap > 0 and gap < 18: target = minf(target,maxf(0,other.speed-(18-gap) * 2))
		r.speed = move_toward(float(r.speed),target,delta * (44 if target < r.speed else 14))
		r.distance += r.speed * delta

func recycle(race: Node3D, r: Dictionary) -> void:
	r.detached = null
	r.respawns += 1
	r.distance = race.distance+600-race.route_node*35+r.id*(38-race.route_node*4)+(int(r.respawns)%3)*11
	r.lane = race.track.lane_centers(r.distance)[(int(r.id)+int(r.respawns))%4]
	r.target_lane = float(r.lane)
	r.speed = float(r.pace)
	r.route_side = (int(r.id)+int(r.respawns))%2

func stage_changed(race: Node3D) -> void:
	var count := mini(race.rivals.size(),8+race.stage_index+race.route_node)
	for r in race.rivals:
		if not r.active and r.id < count: recycle(race,r)
		r.active = r.id < count
