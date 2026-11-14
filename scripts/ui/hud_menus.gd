extends RefCounted
# 키보드·진단 도구가 사용하는 메뉴 연결점. 표시와 입력 좌표는 rev3 화면이 소유한다.
var hud: Control
var race: Node3D:
	get:
		return hud.race


func _init(owner: Control) -> void:
	hud = owner


func draw_garage() -> void:
	hud.rev3.draw_garage()


func graphics_segment(index: int, _row_rect: Rect2 = Rect2()) -> Rect2:
	return hud.rev3.rect("graphics_%d" % index, "settings")


func graphics_index(pos: Vector2) -> int:
	for index in range(3):
		if graphics_segment(index).has_point(pos):
			return index
	return -1


func garage_paint_label() -> String:
	var data: Dictionary = race.customization.selection(race.selected_vehicle, race.passport)
	if data.paint == Color(race.vehicle.paint).to_html(false):
		return "PAINT: ORIGINAL"
	var reward: Dictionary = race.passport.PAINTS[race.passport.paint_index(race.selected_vehicle)]
	if not str(reward.color).is_empty() and data.paint == Color(reward.color).to_html(false):
		return "PAINT: " + str(reward.name)
	return "PAINT: CUSTOM"
