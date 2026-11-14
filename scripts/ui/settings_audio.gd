extends RefCounted
# 슬라이더는 표시와 입력에 같은 좌표를 쓰고 드래그 종료 때만 저장한다.


static func card(hud: Control, music: bool) -> Rect2:
	return hud.rev3.rect("music_panel" if music else "sound_panel", "settings")


static func toggle_rect(hud: Control, music: bool) -> Rect2:
	return hud.rev3.rect("music_toggle" if music else "sound_toggle", "settings")


static func slider_rect(hud: Control, music: bool) -> Rect2:
	return hud.rev3.slider_rect(music)


static func slide(hud: Control, music: bool, pos: Vector2) -> void:
	var rect := slider_rect(hud, music)
	var amount := inverse_lerp(rect.position.x + 12, rect.end.x - 70, pos.x)
	hud.race.set_audio_volume(music, roundi(clampf(amount, 0, 1) * 100), false)


static func begin_drag(hud: Control, pointer: int, pos: Vector2) -> bool:
	for music in [false, true]:
		if slider_rect(hud, music).has_point(pos):
			hud.audio_drags[pointer] = music
			slide(hud, music, pos)
			return true
	return false


static func draw_slider(hud: Control, music: bool) -> void:
	var volume: int = hud.race.audio_preferences.music_volume if music else hud.race.audio_preferences.sound_volume
	hud.rev3.draw_slider(slider_rect(hud, music), volume)
