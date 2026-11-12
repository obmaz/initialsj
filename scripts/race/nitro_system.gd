extends RefCounted
const INPUT_BUFFER := .22
const SHOT_PAUSE_BUDGET := .25


# 샷은 누름 단위로 소비한다. 짧은 드리프트 전환만 대기하며 큰 실수는 취소한다.
static func update(race: Node3D, delta: float, held: bool, cell: bool) -> void:
	var v: Dictionary = race.vehicle
	var pressed: bool = held and not race.nitro_previous_input
	var cell_pressed: bool = cell and not race.cell_previous_input
	race.nitro_previous_input = held
	race.cell_previous_input = cell
	race.nitro_cooldown = maxf(0, race.nitro_cooldown - delta)
	race.nitro_buffer = maxf(0, race.nitro_buffer - delta)
	race.cell_buffer = maxf(0, race.cell_buffer - delta)
	var hard_block: bool = race.braking or race.impact >= .15 or race.world_race.contact_flow.sustained()
	if hard_block:
		race.nitro_burst_left = 0
		race.nitro_pending = false
		race.cell_pending = false
		race.nitro_buffer = 0
		race.cell_buffer = 0
	else:
		if pressed and v.mode == "charges" and race.nitro_charges > 0 and race.nitro_burst_left <= 0:
			race.nitro_pending = true
			race.nitro_buffer = INPUT_BUFFER
		if cell_pressed and v.mode == "hybrid" and race.nitro_charges > 0 and race.nitro_burst_left <= 0:
			race.cell_pending = true
			race.cell_buffer = INPUT_BUFFER
	if not held and race.nitro_buffer <= 0:
		race.nitro_pending = false
	if not cell and race.cell_buffer <= 0:
		race.cell_pending = false
	var blocked: bool = hard_block or race.drifting
	if race.drifting and race.nitro_burst_left > 0:
		race.nitro_pause += delta
		if race.nitro_pause > SHOT_PAUSE_BUDGET:
			race.nitro_burst_left = 0
	if (
		race.nitro_burst_left <= 0
		and race.nitro_cooldown <= 0
		and race.speed > 25
		and race.throttling
		and not blocked
		and race.nitro_charges > 0
		and (race.nitro_pending or race.cell_pending)
	):
		race.nitro_charges -= 1
		race.nitro_burst_left = v.burst_duration
		race.nitro_pause = 0
		race.nitro_pending = false
		race.cell_pending = false
		race.nitro_buffer = 0
		race.cell_buffer = 0
	var burst: bool = race.nitro_burst_left > 0
	if race.nitro <= 0:
		race.nitro_locked = true
	if race.nitro >= 12:
		race.nitro_locked = false
	var gauge: bool = v.mode != "charges" and held and race.nitro > 0 and not race.nitro_locked
	var was_active: bool = race.nitro_active
	race.nitro_active = race.throttling and not blocked and race.speed > 25 and (burst or gauge)
	if race.nitro_active and not was_active:
		race.haptics.pulse(.5, .7, .25, 2)
	if race.nitro_active:
		race.nitro_seconds += delta
		if not burst:
			race.nitro = maxf(0, race.nitro - delta * v.drain)
	elif v.mode != "charges":
		race.nitro = minf(100, race.nitro + delta * (v.drift_regen if race.drifting else v.regen))
	if burst and not race.drifting:
		race.nitro_burst_left = maxf(0, race.nitro_burst_left - delta)
		if race.nitro_burst_left <= 0:
			race.nitro_cooldown = .35
	if (
		v.mode in ["charges", "hybrid"]
		and not race.nitro_active
		and not race.braking
		and race.impact < .15
		and race.speed > 5
	):
		if race.nitro_charges < v.charges:
			race.shot_recharge += delta * (8.0 if race.drifting else 4.0)
			if race.shot_recharge >= 100:
				race.nitro_charges += 1
				race.shot_recharge = 0
		else:
			race.shot_recharge = 0
