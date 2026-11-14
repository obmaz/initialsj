extends RefCounted
# 자유 배치 대신 겹치지 않는 검증된 프리셋을 제공한다. 설계 좌표는 1280×720이다.
const SIZES := [.9, 1.0, 1.08]
const BASE := {
	"drift": Rect2(964, 384, 132, 136),
	"cell": Rect2(826, 418, 108, 108),
	"nitro": Rect2(1110, 384, 134, 136),
	"gas": Rect2(1067, 530, 154, 154),
	"brake": Rect2(890, 541, 132, 132),
	"pause": preload("res://scripts/ui/race_hud_layout.gd").PAUSE
}
var mirrored := false
var size_index := 1
var cache_key := -1
var cached: Dictionary = {}


func read(config: ConfigFile) -> void:
	var side: Variant = config.get_value("touch_layout", "mirrored", false)
	var size: Variant = config.get_value("touch_layout", "size", 1)
	mirrored = side if side is bool else false
	size_index = size if size is int and size >= 0 and size < SIZES.size() else 1


func write(config: ConfigFile) -> void:
	config.set_value("touch_layout", "mirrored", mirrored)
	config.set_value("touch_layout", "size", size_index)


func reset() -> void:
	mirrored = false
	size_index = 1


func rectangles(auto_accelerate: bool) -> Dictionary:
	var key := size_index + (3 if mirrored else 0) + (6 if auto_accelerate else 0)
	if key == cache_key:
		return cached
	cache_key = key
	cached = BASE.duplicate()
	for action in cached:
		if action == "pause":
			continue
		var rect: Rect2 = BASE[action]
		if mirrored:
			rect.position.x = 1280 - rect.end.x
		var size: Vector2 = (rect.size * SIZES[size_index]).max(Vector2(96, 96))
		cached[action] = Rect2(rect.get_center() - size * .5, size)
	if auto_accelerate:
		cached.brake = cached.gas
	return cached
