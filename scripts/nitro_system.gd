extends RefCounted
# Tap shots are edge triggered; holding a button never spends the next charge.
static func update(race: Node3D, delta: float, held: bool, cell: bool) -> void:
	var v: Dictionary = race.vehicle
	var pressed: bool = held and not race.nitro_previous_input
	var cell_pressed: bool = cell and not race.cell_previous_input
	race.nitro_previous_input = held
	race.cell_previous_input = cell
	race.nitro_cooldown = maxf(0,race.nitro_cooldown-delta)
	if not held: race.nitro_pending = false
	if not cell: race.cell_pending = false
	var blocked: bool = race.braking or race.drifting or race.impact >= 0.15
	if blocked:
		race.nitro_burst_left = 0
		race.nitro_pending = false
		race.cell_pending = false
	elif race.nitro_burst_left <= 0 and race.nitro_cooldown <= 0:
		if pressed and v.mode == "charges": race.nitro_pending = true
		if cell_pressed and v.mode == "hybrid": race.cell_pending = true
	if race.nitro_burst_left <= 0 and race.speed > 25 and race.throttling and not blocked and race.nitro_charges > 0 and (race.nitro_pending or race.cell_pending):
		race.nitro_charges -= 1
		race.nitro_burst_left = v.burst_duration
		race.nitro_pending = false
		race.cell_pending = false
	var burst: bool = race.nitro_burst_left > 0
	if race.nitro <= 0: race.nitro_locked = true
	if race.nitro >= 12: race.nitro_locked = false
	var gauge: bool = v.mode != "charges" and held and race.nitro > 0 and not race.nitro_locked
	var was_active: bool = race.nitro_active
	race.nitro_active = race.throttling and not blocked and race.speed > 25 and (burst or gauge)
	if race.nitro_active and not was_active: race.haptics.pulse(0.5,0.7,0.25,2)
	if race.nitro_active:
		race.nitro_seconds += delta
		if not burst: race.nitro = maxf(0,race.nitro-delta*v.drain)
	elif v.mode != "charges":
		race.nitro = minf(100,race.nitro+delta*(v.drift_regen if race.drifting else v.regen))
	if burst:
		race.nitro_burst_left = maxf(0,race.nitro_burst_left-delta)
		if race.nitro_burst_left <= 0: race.nitro_cooldown = 0.35
