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


static func result_target(race: Node3D) -> String:
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
			target = (
				race.tr("NEXT: %s / <= %s")
				% [race.tr("SILVER" if race.run_medal == 1 else "GOLD"), race.hud.time_label(seconds)]
			)
	return race.tr(target)
