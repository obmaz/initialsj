extends RefCounted
const RaceState = preload("res://scripts/race/race_state.gd")
const Challenge = preload("res://scripts/race/tour_challenge.gd")


static func draw_split(hud: Control) -> void:
	var race: Node3D = hud.race
	var run: RefCounted = race.personal_run
	if race.state != RaceState.RACING or run.split_flash <= 0:
		return
	var rect := Rect2(15, 235, 224, 56)
	hud.slant(rect, hud.INK, 7)
	hud.text_at(rect.position + Vector2(12, 19), run.split_label + (" / BEST" if run.split_new else ""), 14, hud.CYAN)
	hud.text_at(
		rect.position + Vector2(12, 45), "%+.2fs" % run.split_delta, 25, hud.GOLD if run.split_new else hud.WHITE
	)


static func draw_result(hud: Control) -> void:
	var race: Node3D = hud.race
	if race.state not in RaceState.ENDED:
		return
	hud.text_at(
		Vector2(307, 592),
		(
			"EXIT %d / DRIFT x%d / PASS x%d / HITS %d / RESET %d"
			% [
				race.rewards.clean_exits,
				race.max_drift_multiplier,
				race.rewards.max_pass_chain,
				race.wall_hits + race.traffic_hits,
				race.personal_run.recoveries
			]
		),
		20,
		hud.CYAN
	)
	var target := "NEXT: FINISH THE RUN"
	if race.state == RaceState.FINISHED:
		if race.run_medal >= 3:
			target = "NEXT: NO HITS / NO RESETS"
		elif race.mode == "track":
			target = "NEXT: GOLD / FINISH 1ST" if race.run_medal == 2 else "NEXT: SILVER / FINISH TOP 3"
		else:
			var seconds := Challenge.target_seconds(race.track.history, race.vehicle.max_speed)
			if race.run_medal == 1:
				seconds *= 1.16
			target = "NEXT: %s / <= %s" % ["SILVER" if race.run_medal == 1 else "GOLD", hud.time_label(seconds)]
	hud.text_at(Vector2(307, 626), target, 20, hud.GOLD)
	hud.text_at(
		Vector2(307, 658),
		"JUMP %d / SAFE LINE %d" % [race.route_challenges.skill_jumps, race.route_challenges.safe_passes],
		16,
		hud.CYAN
	)
	if race.mode == "track" and race.state == RaceState.FINISHED:
		hud.text_at(
			Vector2(307, 322),
			Challenge.medal_label(race.run_medal) + " / RESETS %d" % race.personal_run.recoveries,
			19,
			hud.CYAN
		)

	if not race.passport.new_unlocks.is_empty():
		hud.text_at(Vector2(307, 676), "UNLOCK: " + " / ".join(race.passport.new_unlocks.slice(0, 2)), 14, hud.GOLD)
	hud.text_at(
		Vector2(780, 289), "BEST SCORE %d" % int(race.passport.high_scores.get(race.record_key(), 0)), 16, hud.CYAN
	)
