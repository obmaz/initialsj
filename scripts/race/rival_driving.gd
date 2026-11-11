extends RefCounted
# 플레이어 입력·순위에 따른 성능 보정 없이, 차종과 고정 성격으로 판단한다.
const Catalog = preload("res://scripts/vehicles/vehicle_catalog.gd")
const STYLES := [
	{"name": "STEADY", "pace": 0.96, "corner": 0.88, "lane_cost": 1.35, "boost_curve": 0.0018},
	{"name": "SPRINTER", "pace": 1.02, "corner": 0.85, "lane_cost": 0.95, "boost_curve": 0.0014},
	{"name": "TECHNICAL", "pace": 0.99, "corner": 1.02, "lane_cost": 1.1, "boost_curve": 0.0022},
	{"name": "ATTACKER", "pace": 1.0, "corner": 0.95, "lane_cost": 0.8, "boost_curve": 0.0018}
]


static func reset(rival: RefCounted, index: int) -> void:
	rival.vehicle_index = index % Catalog.SPECS.size()
	rival.specification = Catalog.spec(rival.vehicle_index)
	rival.style = STYLES[(index + int(index / 4)) % STYLES.size()]
	rival.boost_energy = rival.specification.energy_start
	rival.boost_charges = rival.specification.charges
	rival.boost_left = 0
	rival.boost_cooldown = 0
	rival.boost_lap = 0
	rival.corner_memory = 0
	rival.nitro_active = false
	rival.boost_cell = false


static func nitro(rival: RefCounted, delta: float, curve: float, speed: float, clear: bool) -> bool:
	var spec: Dictionary = rival.specification
	rival.boost_cooldown = maxf(0, rival.boost_cooldown - delta)
	rival.corner_memory = 2.0 if curve > 0.003 else maxf(0, rival.corner_memory - delta)
	if not clear or speed < 25:
		rival.boost_left = 0
		rival.nitro_active = false
		rival.boost_energy = minf(100, rival.boost_energy + float(spec.regen) * delta)
		return false
	var safe: bool = curve < float(rival.style.boost_curve)
	var wants: bool = safe and (rival.style.name != "TECHNICAL" or rival.corner_memory > 0)
	if spec.mode == "gauge":
		wants = wants and rival.boost_energy > 25
	elif spec.mode == "hybrid":
		wants = wants and (rival.boost_energy > 25 or rival.boost_charges > 0)
	if rival.boost_left <= 0 and rival.boost_cooldown <= 0 and wants:
		if spec.mode == "charges":
			if rival.boost_charges > 0:
				rival.boost_charges -= 1
				rival.boost_left = spec.burst_duration
		else:
			rival.boost_cell = spec.mode == "hybrid" and rival.boost_energy <= 25
			if rival.boost_cell:
				rival.boost_charges -= 1
			rival.boost_left = float(spec.burst_duration) if rival.boost_cell else 1.1
	var active: bool = (
		rival.boost_left > 0 and safe and (spec.mode == "charges" or rival.boost_cell or rival.boost_energy > 0)
	)
	if active:
		rival.boost_left = maxf(0, rival.boost_left - delta)
		if spec.mode != "charges" and not rival.boost_cell:
			rival.boost_energy = maxf(0, rival.boost_energy - float(spec.drain) * delta)
		if rival.boost_left <= 0:
			rival.boost_cooldown = 2.0
	else:
		rival.boost_left = 0
		rival.boost_energy = minf(100, rival.boost_energy + float(spec.regen) * delta)
	rival.nitro_active = active
	return active
