extends RefCounted
# 슬라이더는 80px 높이의 입력 영역을 사용하고 드래그 종료 때만 저장한다.
const MenuTheme = preload("res://scripts/ui/menu_theme.gd")


static func card(hud: Control, music: bool) -> Rect2:
	return hud.SETTINGS_MUSIC if music else hud.SETTINGS_SOUND


static func toggle_rect(hud: Control, music: bool) -> Rect2:
	var rect := card(hud, music)
	rect.size.y = 80
	return rect


static func slider_rect(hud: Control, music: bool) -> Rect2:
	var rect := card(hud, music)
	return Rect2(rect.position + Vector2(16, 80), Vector2(rect.size.x - 96, 80))


static func slide(hud: Control, music: bool, pos: Vector2) -> void:
	var rect := slider_rect(hud, music)
	var amount := inverse_lerp(rect.position.x + 12, rect.end.x - 12, pos.x)
	hud.race.set_audio_volume(music, roundi(clampf(amount, 0, 1) * 100), false)


static func begin_drag(hud: Control, pointer: int, pos: Vector2) -> bool:
	for music in [false, true]:
		var rect := card(hud, music)
		if rect.has_point(pos) and pos.y >= rect.position.y + 80:
			if slider_rect(hud, music).has_point(pos):
				hud.audio_drags[pointer] = music
				slide(hud, music, pos)
			return true
	return false


static func draw_slider(hud: Control, music: bool) -> void:
	var rect := slider_rect(hud, music)
	var volume: int = hud.race.audio_preferences.music_volume if music else hud.race.audio_preferences.sound_volume
	var start := Vector2(rect.position.x + 12, rect.get_center().y)
	var end := Vector2(rect.end.x - 12, start.y)
	var knob := start.lerp(end, volume / 100.0)
	hud.draw_line(start, end, MenuTheme.MUTED, 5, true)
	hud.draw_line(start, knob, MenuTheme.TEAL, 5, true)
	hud.draw_circle(knob, 11, MenuTheme.TEAL)
	var row := card(hud, music)
	MenuTheme.label(hud, Rect2(row.end.x - 76, rect.position.y, 64, 80), "%d%%" % volume, 24, MenuTheme.INK, true)
