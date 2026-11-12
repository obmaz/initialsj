extends RefCounted
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")
const Library = preload("res://scripts/track/route_library.gd")
const Challenge = preload("res://scripts/race/tour_challenge.gd")


static func draw(hud: Control) -> void:
	var passport: RefCounted = hud.race.passport
	MenuTheme.canvas(hud)
	MenuTheme.button(hud, hud.PASSPORT_CLOSE, "‹ BACK")
	MenuTheme.label(hud, Rect2(330, 20, 600, 68), "TOUR PASSPORT", 40)
	MenuTheme.label(
		hud,
		Rect2(52, 114, 1176, 40),
		(
			hud.race.tr("%d / 5 GOALS") % passport.goals.size()
			+ "   /   "
			+ hud.race.tr("%d / 16 ROUTES") % passport.routes.size()
		),
		26,
		MenuTheme.TEAL
	)
	for index in range(5):
		var theme: String = Library.THEMES[4][index]
		var rect := Rect2(52 + index * 240, 164, 220, 140)
		var medal: int = passport.goals.get(theme, 0)
		MenuTheme.panel(hud, rect, MenuTheme.SOFT if medal > 0 else MenuTheme.PAPER)
		MenuTheme.label(
			hud, Rect2(rect.position + Vector2(12, 6), Vector2(196, 40)), "%02d" % (index + 1), 32, MenuTheme.TEAL, true
		)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(12, 49), Vector2(196, 38)),
			Library.TITLES[theme],
			24,
			MenuTheme.INK,
			true
		)
		MenuTheme.label(
			hud,
			Rect2(rect.position + Vector2(12, 92), Vector2(196, 36)),
			Challenge.medal_label(medal) if medal > 0 else "UNVISITED",
			23,
			MenuTheme.MUTED,
			true
		)
	MenuTheme.label(hud, Rect2(52, 316, 1176, 40), "YOUR ROUTES / L = LEFT, R = RIGHT", 24, MenuTheme.TEAL)
	for index in range(16):
		var route := ""
		for bit in range(4):
			route += "R" if (index >> bit) & 1 else "L"
		var medal: int = passport.routes.get(route, 0)
		var rect := Rect2(52 + (index % 4) * 300, 364 + int(index / 4) * 44, 280, 36)
		MenuTheme.panel(hud, rect, MenuTheme.SOFT if medal > 0 else MenuTheme.PAPER, false, 6)
		MenuTheme.label(
			hud, rect.grow(-4), route + "   " + hud.race.tr(Challenge.medal_label(medal)), 23, MenuTheme.INK, true
		)
	var unlocked: Array[int] = passport.unlocked_paints()
	for index in range(passport.PAINTS.size()):
		var x := 52.0 + index * 240
		var color := Color("b6c3cd") if index == 0 else Color(passport.PAINTS[index].color)
		hud.draw_rect(Rect2(x, 552, 220, 6), color if index in unlocked else MenuTheme.BORDER)
		MenuTheme.label(hud, Rect2(x, 568, 220, 34), passport.PAINTS[index].name, 24, MenuTheme.INK)
		hud.menu_text.draw_wrapped(
			Rect2(x, 604, 220, 60),
			hud.race.tr("UNLOCKED" if index in unlocked else passport.PAINTS[index].goal),
			24,
			MenuTheme.MUTED
		)

	MenuTheme.label(
		hud, Rect2(52, 674, 1176, 32), "CHANGE PAINT & PLATE IN GARAGE / COSMETICS ONLY", 24, MenuTheme.MUTED, true
	)
