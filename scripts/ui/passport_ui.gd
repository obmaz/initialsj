extends RefCounted
const Library = preload("res://scripts/track/route_library.gd")
const Challenge = preload("res://scripts/race/tour_challenge.gd")


static func draw(hud: Control) -> void:
	var passport: RefCounted = hud.race.passport
	hud.draw_rect(
		Rect2(-hud.ui_offset() / hud.ui_scale(), hud.get_viewport_rect().size / hud.ui_scale()), Color("07111e")
	)
	hud.text_at(Vector2(52, 75), "TOUR PASSPORT", 42, hud.CYAN)
	hud.slant(hud.PASSPORT_CLOSE, Color("20374a"), 8)
	hud.centered(hud.PASSPORT_CLOSE.get_center() + Vector2(0, 10), "< CLOSE", 28)
	hud.text_at(
		Vector2(54, 125),
		(
			"%d/5 DESTINATIONS   /   %d/16 ROUTES   /   CLEAN TOUR %s"
			% [passport.goals.size(), passport.routes.size(), "YES" if passport.clean_tour else "--"]
		),
		24,
		hud.WHITE
	)
	for index in range(5):
		var theme: String = Library.THEMES[4][index]
		var rect := Rect2(52 + index * 240, 156, 220, 174)
		var medal: int = passport.goals.get(theme, 0)
		hud.slant(rect, Color("163547") if medal > 0 else Color("111e2b"), 12)
		hud.centered(
			rect.position + Vector2(110, 56), "%02d" % (index + 1), 40, hud.GOLD if medal > 0 else Color("567184")
		)
		hud.centered(rect.position + Vector2(110, 102), Library.TITLES[theme], 21, hud.WHITE)
		hud.centered(
			rect.position + Vector2(110, 143), Challenge.medal_label(medal) if medal > 0 else "UNVISITED", 19, hud.CYAN
		)
	hud.text_at(Vector2(54, 373), "YOUR ROUTES / L = LEFT, R = RIGHT", 24, hud.CYAN)
	for index in range(16):
		var route := ""
		for bit in range(4):
			route += "R" if (index >> bit) & 1 else "L"
		var medal: int = passport.routes.get(route, 0)
		var rect := Rect2(52 + (index % 4) * 300, 394 + int(index / 4) * 46, 280, 36)
		hud.slant(rect, Color("193b4c") if medal > 0 else Color("111e2b"), 6)
		hud.text_at(
			rect.position + Vector2(14, 25),
			route + "   " + Challenge.medal_label(medal),
			19,
			hud.GOLD if medal > 0 else Color("688396")
		)
	var unlocked: Array[int] = passport.unlocked_paints()
	for index in range(passport.PAINTS.size()):
		var x := 52.0 + index * 240
		var color := Color("b6c3cd") if index == 0 else Color(passport.PAINTS[index].color)
		hud.draw_rect(Rect2(x, 600, 220, 6), color if index in unlocked else Color("263746"))
		hud.text_at(Vector2(x, 636), passport.PAINTS[index].name, 18, color if index in unlocked else Color("688396"))
		hud.text_at(Vector2(x, 662), "UNLOCKED" if index in unlocked else passport.PAINTS[index].goal, 12, hud.WHITE)
	hud.centered(Vector2(640, 702), "CHANGE PAINT & PLATE IN GARAGE / COSMETICS ONLY", 16, Color("8eacbe"))
