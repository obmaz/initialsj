extends RefCounted
# 중계 장면의 오른쪽만 사용하는 결과 카드. 나머지 화면에는 덮개를 그리지 않는다.
const State = preload("res://scripts/race/race_state.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const Challenges = preload("res://scripts/ui/driving_challenges_ui.gd")
const PANEL := Rect2(820, 48, 420, 650)


static func label(hud: Control, y: float, key: String, size: int = 26, color: Color = MenuTheme.INK) -> void:
	MenuTheme.label(hud, Rect2(846, y, 368, 42), key, size, color)


static func draw(hud: Control) -> void:
	var race: Node3D = hud.race
	if race.result_age < 1.2:
		return
	var finished: bool = race.state == State.FINISHED
	MenuTheme.panel(hud, PANEL, Color(1, .99, .96, 1), true, 18)
	label(hud, 65, "INITIAL SJ", 22, MenuTheme.TEAL)
	var title := ("RACE FINISHED" if race.mode == "track" else "GOAL CLEAR!") if finished else "TIME OVER"
	label(hud, 103, title, 38, MenuTheme.INK if finished else MenuTheme.TEAL)
	var detail: String = (
		race.tr("POS %d / %d") % [race.race_position(), race.competitor_count()]
		if race.mode == "track" and finished
		else race.vehicle.name
	)
	label(hud, 157, detail, 30)
	var medal: String = race.TourChallenge.medal_label(race.run_medal) if finished else race.course_title
	if race.mode == "tour":
		medal = race.tr("ROUTE %s") % race.TourChallenge.route_id(race.track.history)
	label(hud, 195, medal, 22, MenuTheme.TEAL)
	label(hud, 238, "THIS RUN", 22, MenuTheme.MUTED)
	label(hud, 271, hud.time_label(race.elapsed), 38)
	label(hud, 322, "NEW RECORD!" if finished and race.new_record else "BEST", 22, MenuTheme.TEAL)
	label(hud, 355, hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---", 36)
	label(hud, 405, race.tr("SCORE %d") % int(race.score), 27)
	label(hud, 447, race.tr("EXIT %d / DRIFT x%d") % [race.rewards.clean_exits, race.max_drift_multiplier], 22)
	label(
		hud,
		480,
		(
			race.tr("PASS x%d / HITS %d / RESET %d")
			% [race.rewards.max_pass_chain, race.wall_hits + race.traffic_hits, race.personal_run.recoveries]
		),
		22
	)
	var target: String = Challenges.result_target(race)
	hud.menu_text.draw_wrapped(Rect2(846, 519, 368, 52), target, 22, MenuTheme.TEAL)
	if not race.passport.new_unlocks.is_empty():
		label(hud, 568, race.tr("UNLOCK: %s") % race.passport.new_unlocks[0], 22, MenuTheme.TEAL)
	MenuTheme.button(hud, hud.result_continue_rect(), race.result_button_label(), MenuTheme.YELLOW, 28)
