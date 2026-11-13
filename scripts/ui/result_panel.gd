extends RefCounted
# 실제 중계 화면의 오른쪽만 사용하는 네온 결과 카드. 데이터·입력 영역은 경기 정본을 따른다.
const State = preload("res://scripts/race/race_state.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const Challenges = preload("res://scripts/ui/driving_challenges_ui.gd")
const Chrome = preload("res://scripts/ui/neon_chrome.gd")
const PANEL := Rect2(724, 44, 520, 656)
const GOLD := Color("ffdc78")
const CYAN := Color("46edff")


static func label(
	hud: Control,
	rect: Rect2,
	key: String,
	size: int = 24,
	color: Color = Color.WHITE,
	centered: bool = false,
	minimum: int = 18
) -> void:
	MenuTheme.label(hud, rect, key, size, color, centered, minimum)


static func draw_tile(hud: Control, rect: Rect2, title: String, val: String, val_color: Color = Color.WHITE) -> void:
	hud.glass_box(rect, 12, Color("061c2cf5"), Color("51e5f4"), 1.8)
	hud.draw_line(
		rect.position + Vector2(12, 4), Vector2(rect.end.x - 12, rect.position.y + 4), Color("b1f9ff80"), 1, true
	)
	label(
		hud, Rect2(rect.position + Vector2(12, 7), Vector2(rect.size.x - 24, 24)), title, 18, Color("a1c5d7"), false, 14
	)
	label(hud, Rect2(rect.position + Vector2(12, 32), Vector2(rect.size.x - 24, 44)), val, 33, val_color, false, 22)


static func draw(hud: Control) -> void:
	var race: Node3D = hud.race
	if race.result_age < 1.2:
		return
	var finished: bool = race.state == State.FINISHED
	var place: int = race.race_position()
	var winner: bool = finished and (race.mode != "track" or place == 1)
	var accent := GOLD if winner else (CYAN if finished else Color("ff8c76"))
	hud.modal_begin()
	Chrome.panel(hud, PANEL, CYAN, 22, Color("051825fc"), 2.8)
	label(hud, Rect2(PANEL.position + Vector2(22, 12), Vector2(180, 24)), "INITIAL SJ", 16, CYAN, false, 13)
	var badge: String = race.TourChallenge.medal_label(race.run_medal) if finished else race.course_title
	if race.mode == "tour":
		badge = race.tr("ROUTE %s") % race.TourChallenge.route_id(race.track.history)
	label(hud, Rect2(PANEL.end.x - 164, PANEL.position.y + 12, 140, 24), badge, 16, accent, true, 13)

	# 벡터 장식을 사용해 별·트로피가 누락된 글꼴에서도 같은 모양으로 표시된다.
	var emblem := PANEL.position + Vector2(PANEL.size.x * .5, 56)
	if finished:
		Chrome.trophy(hud, emblem, 62, accent)
		for side in [-1, 1]:
			var stem := PackedVector2Array()
			for i in range(7):
				var at := emblem + Vector2(side * (43 + sin(i * PI / 7) * 12), 26 - i * 9)
				stem.append(at)
				if i < 6:
					hud.draw_colored_polygon(
						PackedVector2Array(
							[at, at + Vector2(side * 2, -10), at + Vector2(side * 9, -15), at + Vector2(side * 8, -5)]
						),
						accent
					)
			hud.draw_polyline(stem, accent, 1.6, true)
	else:
		hud.draw_circle(emblem, 27, Color("3b202a"))
		hud.draw_arc(emblem, 29, 0, TAU, 48, accent, 2.5, true)
		hud.draw_rect(Rect2(emblem + Vector2(-3, -16), Vector2(6, 20)), accent)
		hud.draw_circle(emblem + Vector2(0, 13), 3.5, accent)

	var heading := (
		"1ST PLACE"
		if winner and race.mode == "track"
		else ("GOAL CLEAR!" if finished and race.mode != "track" else ("RACE FINISHED" if finished else "TIME OVER"))
	)
	var title_rect := Rect2(PANEL.position + Vector2(60, 98), Vector2(PANEL.size.x - 120, 54))
	Chrome.panel(hud, title_rect, accent, 18, Color("122735"), 2.4)
	Chrome.star(hud, PANEL.position + Vector2(32, 125), 11, accent)
	Chrome.star(hud, Vector2(PANEL.end.x - 32, PANEL.position.y + 125), 11, accent)
	label(hud, title_rect.grow(-9), heading, 31, accent, true, 22)
	var vehicle_name: String = race.vehicle.name
	if race.mode == "track" and finished and place != 1:
		vehicle_name = race.tr("POS %d / %d") % [place, race.competitor_count()] + "  /  " + vehicle_name
	label(
		hud,
		Rect2(PANEL.position + Vector2(24, 157), Vector2(PANEL.size.x - 48, 29)),
		vehicle_name,
		23,
		Color("acd3e9"),
		true,
		17
	)

	# 2×2 기록 타일과 두 정보 띠를 continue 위까지 채워 큰 빈칸을 만들지 않는다.
	var left: float = PANEL.position.x + 24
	var inner_width: float = PANEL.size.x - 48
	var column: float = (inner_width - 12) * .5
	var top: float = PANEL.position.y + 196
	var height := 84.0
	draw_tile(hud, Rect2(left, top, column, height), "RUN TIME", hud.time_label(race.elapsed))
	var is_new: bool = finished and race.new_record
	var best: String = hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---"
	draw_tile(
		hud,
		Rect2(left + column + 12, top, column, height),
		"NEW RECORD!" if is_new else "BEST TIME",
		best,
		GOLD if is_new else CYAN
	)
	draw_tile(hud, Rect2(left, top + height + 10, column, height), "SCORE", "%d PTS" % int(race.score), GOLD)
	var technique: String = "DRIFT x%d" % race.max_drift_multiplier
	if race.rewards.clean_exits > 0:
		technique += " (EX %d)" % race.rewards.clean_exits
	draw_tile(hud, Rect2(left + column + 12, top + height + 10, column, height), "TECHNIQUE", technique, CYAN)

	var detail_rect := Rect2(left, PANEL.position.y + 386, inner_width, 52)
	hud.glass_box(detail_rect, 10, Color("071e2df5"), Color("50e9f4"), 1.6)
	var detail: String = (
		race.tr("PASS x%d  |  HITS %d  |  RESET %d")
		% [race.rewards.max_pass_chain, race.wall_hits + race.traffic_hits, race.personal_run.recoveries]
	)
	label(hud, detail_rect.grow(-10), detail, 21, Color("d7ecf7"), true, 16)

	var target_rect := Rect2(left, PANEL.position.y + 450, inner_width, 56)
	hud.glass_box(target_rect, 10, Color("071e2df5"), Color("50e9f4"), 1.6)
	hud.menu_text.draw_wrapped(
		Rect2(target_rect.position + Vector2(10, 4), Vector2(inner_width - 20, 48)),
		Challenges.result_target(race),
		20,
		Color("b5f5ff")
	)

	var unlock_rect := Rect2(left, PANEL.position.y + 518, inner_width, 34)
	hud.glass_box(unlock_rect, 10, Color("102c38"), Color("50e9f4"), 1.6)
	Chrome.star(hud, unlock_rect.position + Vector2(20, 17), 9, GOLD)
	var unlock: String = race.course_title if race.mode == "track" else race.TourChallenge.medal_label(race.run_medal)
	if not race.passport.new_unlocks.is_empty():
		unlock = race.tr("UNLOCK: %s") % race.passport.new_unlocks[0]
	label(hud, Rect2(unlock_rect.position + Vector2(38, 2), Vector2(inner_width - 48, 30)), unlock, 20, GOLD, false, 16)

	var button: Rect2 = hud.result_continue_rect()
	Chrome.panel(hud, button, Color("a4ffff"), 14, Color("086f7e"), 3)
	label(hud, button.grow(-12), race.result_button_label(), 28, Color.WHITE, true, 22)
	hud.modal_end()
