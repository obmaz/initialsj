extends RefCounted
# 중계 장면의 오른쪽을 사용하는 다크 글래스모피즘 빅토리 카드.
const State = preload("res://scripts/race/race_state.gd")
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const Challenges = preload("res://scripts/ui/driving_challenges_ui.gd")
const PANEL := Rect2(820, 44, 424, 656)


static func label(
	hud: Control,
	rect: Rect2,
	key: String,
	size: int = 24,
	color: Color = Color.WHITE,
	centered: bool = false,
	minimum: int = 14
) -> void:
	MenuTheme.label(hud, rect, key, size, color, centered, minimum)


static func draw_tile(hud: Control, rect: Rect2, title: String, val: String, val_color: Color = Color.WHITE) -> void:
	hud.glass_box(rect, 10.0, Color("0f1e36cc"), Color("00e5ff44"), 1.0)
	MenuTheme.label(
		hud,
		Rect2(rect.position.x + 10, rect.position.y + 6, rect.size.x - 20, 18),
		title,
		14,
		Color("78909c"),
		false,
		10
	)
	MenuTheme.label(
		hud, Rect2(rect.position.x + 10, rect.position.y + 26, rect.size.x - 20, 32), val, 22, val_color, false, 14
	)


static func draw(hud: Control) -> void:
	var race: Node3D = hud.race
	if race.result_age < 1.2:
		return
	var finished: bool = race.state == State.FINISHED

	# 1. 다크 글래스모피즘 메인 빅토리 카드 (딥 네이비 글래스 + 네온 시안 테두리)
	hud.glass_box(PANEL, 20.0, Color("081220f4"), Color("00e5ff66"), 1.5)

	# 상단 포인트 네온 라인
	hud.draw_line(
		Vector2(PANEL.position.x + 28, PANEL.position.y + 2),
		Vector2(PANEL.end.x - 28, PANEL.position.y + 2),
		Color("00e5ffaa"),
		2.0
	)

	# 2. 헤더 브랜드 & 코스/루트 표시
	MenuTheme.label(
		hud, Rect2(PANEL.position.x + 20, PANEL.position.y + 14, 180, 22), "INITIAL SJ", 18, Color("00e5ff"), false, 14
	)
	var medal: String = race.TourChallenge.medal_label(race.run_medal) if finished else race.course_title
	if race.mode == "tour":
		medal = race.tr("ROUTE %s") % race.TourChallenge.route_id(race.track.history)
	MenuTheme.label(hud, Rect2(PANEL.end.x - 210, PANEL.position.y + 14, 190, 22), medal, 18, Color("8bc34a"), true, 14)

	# 3. 메인 타이틀 & 순위 엠블럼
	var title: String = ""
	var title_color: Color = Color.WHITE
	if finished:
		if race.mode == "track":
			var pos: int = race.race_position()
			if pos == 1:
				title = "★ 1ST PLACE ★"
				title_color = Color("ffd700")
			else:
				title = race.tr("RACE FINISHED (POS %d/%d)") % [pos, race.competitor_count()]
				title_color = Color("00e5ff")
		else:
			title = "GOAL CLEAR!"
			title_color = Color("00e5ff")
	else:
		title = "TIME OVER"
		title_color = Color("ff5252")
	MenuTheme.label(
		hud,
		Rect2(PANEL.position.x + 20, PANEL.position.y + 44, PANEL.size.x - 40, 44),
		title,
		34,
		title_color,
		true,
		20
	)

	# 차량 이름 뱃지
	MenuTheme.label(
		hud,
		Rect2(PANEL.position.x + 20, PANEL.position.y + 90, PANEL.size.x - 40, 26),
		race.vehicle.name,
		20,
		Color("90caf9"),
		true,
		14
	)

	# 4. 2x2 통계 그리드 타일 슬롯
	var gx: float = PANEL.position.x + 20
	var gy: float = PANEL.position.y + 126
	var gw: float = (PANEL.size.x - 52) * 0.5
	var gh: float = 64.0

	# 타일 1: 주행 시간
	draw_tile(hud, Rect2(gx, gy, gw, gh), "RUN TIME", hud.time_label(race.elapsed), Color.WHITE)

	# 타일 2: 최고 기록
	var is_new: bool = finished and race.new_record
	var best_title: String = "NEW RECORD!" if is_new else "BEST TIME"
	var best_color: Color = Color("ffd700") if is_new else Color("00e5ff")
	var best_str: String = hud.time_label(race.best_time) if race.best_time > 0 else "--:--.---"
	draw_tile(hud, Rect2(gx + gw + 12, gy, gw, gh), best_title, best_str, best_color)

	# 타일 3: 점수
	draw_tile(hud, Rect2(gx, gy + gh + 10, gw, gh), "SCORE", "%d PTS" % int(race.score), Color("ffeb3b"))

	# 타일 4: 테크닉 (드리프트 & 클린 엑시트)
	var tech_str: String = "DRIFT x%d" % race.max_drift_multiplier
	if race.rewards.clean_exits > 0:
		tech_str += " (EX %d)" % race.rewards.clean_exits
	draw_tile(hud, Rect2(gx + gw + 12, gy + gh + 10, gw, gh), "TECHNIQUE", tech_str, Color("00e5ff"))

	# 5. 세부 주행 상세 슬롯
	var dy: float = gy + (gh + 10) * 2
	var dw: float = PANEL.size.x - 40
	hud.glass_box(Rect2(gx, dy, dw, 48), 10.0, Color("0a1424b0"), Color("00e5ff33"), 1.0)
	var detail_text: String = (
		race.tr("PASS x%d  |  HITS %d  |  RESET %d")
		% [race.rewards.max_pass_chain, race.wall_hits + race.traffic_hits, race.personal_run.recoveries]
	)
	MenuTheme.label(hud, Rect2(gx + 10, dy + 12, dw - 20, 24), detail_text, 18, Color("cfd8dc"), true, 12)

	# 6. 챌린지 타깃 & 신규 언락 슬롯
	var cy: float = dy + 58
	var target: String = Challenges.result_target(race)
	hud.glass_box(Rect2(gx, cy, dw, 48), 10.0, Color("0a1424b0"), Color("00e5ff22"), 1.0)
	hud.menu_text.draw_wrapped(Rect2(gx + 12, cy + 10, dw - 24, 28), target, 18, Color("80deea"))

	var uy: float = cy + 56
	if not race.passport.new_unlocks.is_empty():
		hud.glass_box(Rect2(gx, uy, dw, 44), 10.0, Color("ffd70022"), Color("ffd70088"), 1.0)
		MenuTheme.label(
			hud,
			Rect2(gx + 12, uy + 10, dw - 24, 24),
			"★ UNLOCK: %s" % race.passport.new_unlocks[0],
			18,
			Color("ffd700"),
			true,
			12
		)

	# 7. 하단 네온 컨티뉴 버튼 (글래스모피즘 + 시안 글로우)
	var btn_rect: Rect2 = hud.result_continue_rect()
	hud.glass_box(btn_rect, 14.0, Color("00e5ff33"), Color("00e5ff"), 2.0)
	MenuTheme.label(hud, btn_rect, race.result_button_label(), 28, Color("00e5ff"), true, 20)
