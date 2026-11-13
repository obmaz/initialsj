extends RefCounted
# 실제 입력 Rect를 한 번 기록하고 같은 좌표계에 짧은 눌림·반사만 표시한다.
var rect := Rect2()
var state := ""
var age := 1.0
const DURATION := .22


func press(at: Vector2, bounds: Array[Rect2], screen: String) -> bool:
	for target in bounds:
		if target.has_area() and target.has_point(at):
			rect = target
			state = screen
			age = 0
			return true
	return false


func advance(delta: float, screen: String) -> void:
	age = minf(DURATION, age + maxf(0, delta))
	if screen != state:
		rect = Rect2()


func amount() -> float:
	return (1.0 - age / DURATION) if rect.has_area() else 0.0


func offset_for(bounds: Rect2, reduced: bool) -> Vector2:
	return Vector2(0, 2 * amount()) if not reduced and rect.encloses(bounds) else Vector2.ZERO
