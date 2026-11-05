extends RefCounted

# Everyone obeys the same road and acceleration limits; no positional rubber-banding.
func initialize(rivals: Array[Dictionary]) -> void:
	for i in range(rivals.size()):
		var r: Dictionary = rivals[i]
		r.speed = 0.0
		r.lane = 3.0 if i % 2 == 0 else -3.0
		r.nitro = 65.0 + i * 3
		r.target_lane = float(r.lane)
		r.decision = i * 0.09
		r.boosting = false
		r.pace = 66.5 + i * 0.25

func tick(race: Node3D, delta: float) -> void:
	var traffic: Array[Dictionary] = [{"distance": race.distance, "lane": race.lane, "speed": race.speed}]
	traffic.append_array(race.rivals)
	for r in race.rivals:
		var d: float = r.distance
		var bend: float = wrapf(race.track.heading(d + 55) - race.track.heading(d), -PI, PI)
		r.decision -= delta
		if r.decision <= 0:
			r.decision = 0.28
			var best_cost := INF
			var best_lane: float = r.lane
			for candidate in [-5.4, -2.7, 0.0, 2.7, 5.4]:
				var cost: float = absf(candidate - float(r.lane)) * 0.22 + absf(candidate - signf(bend) * 2.5) * 0.1
				for other in traffic:
					if other == r:
						continue
					var gap: float = wrapf(float(other.distance) - d, -race.track.length / 2, race.track.length / 2)
					if absf(float(other.lane) - candidate) < 2.2:
						if gap > -5 and gap < 30:
							cost += (30 - gap) * (1.0 if other.speed < r.speed + 2 else 0.35)
						if gap < -5 and gap > -15 and other.speed > r.speed:
							cost += 14
					# Check the whole lateral crossing, not only the destination lane.
					if absf(gap) < 6 and other.lane > minf(r.lane, candidate) - 1.7 and other.lane < maxf(r.lane, candidate) + 1.7:
						cost += 120
				if cost < best_cost:
					best_cost = cost
					best_lane = candidate
			r.target_lane = best_lane
		r.lane = move_toward(float(r.lane), float(r.target_lane), delta * 3.8)
		r.lane = clampf(r.lane + bend / 55.0 * r.speed * r.speed * 0.04 * delta, -6.3, 6.3)
		var target: float = minf(68, r.pace) - minf(absf(bend) * 9, 7)
		var lead_gap := INF
		for other in traffic:
			if other == r or absf(float(other.lane) - float(r.lane)) > 2:
				continue
			var gap: float = wrapf(float(other.distance) - d, -race.track.length / 2, race.track.length / 2)
			if gap > 0 and gap < lead_gap:
				lead_gap = gap
				if gap < 12:
					target = minf(target, maxf(12, float(other.speed) - (12 - gap) * 1.8))
		# Save boost for open exits or an adjacent passing lane, never accelerate into a bumper.
		r.boosting = r.nitro > (2 if r.boosting else 38) and absf(bend) < 0.38 and lead_gap > 24 and r.speed > 36
		if r.boosting:
			target = minf(88, target + 19)
			r.nitro = maxf(0, r.nitro - delta * 24)
		else:
			r.nitro = minf(100, r.nitro + delta * 4)
		r.speed = move_toward(float(r.speed), target, delta * (26 if target < r.speed else 20))
		r.distance += r.speed * delta
