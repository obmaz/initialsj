extends RefCounted
# 노드·타이머를 만들지 않는다. 화면 교체 시 이전 닫기 콜백을 취소한다.
const OPEN_SECONDS := .18
const CLOSE_SECONDS := .12
var key := ""
var age := 0.0
var closing := false
var close_age := 0.0
var close_from := 1.0
var completion := Callable()


func advance(next: String, delta: float, reduced: bool, covered: bool = false) -> void:
	if key != next:
		key = next
		age = 0
		closing = false
		completion = Callable()
	if reduced:
		age = OPEN_SECONDS
	if covered:
		age = 0
		return
	if closing:
		close_age += delta
		if close_age >= CLOSE_SECONDS or reduced:
			var action := completion
			completion = Callable()
			closing = false
			if action.is_valid():
				action.call()
	else:
		age = minf(OPEN_SECONDS, age + delta)


func progress() -> float:
	return close_from * (1 - clampf(close_age / CLOSE_SECONDS, 0, 1)) if closing else clampf(age / OPEN_SECONDS, 0, 1)


func transform() -> Transform2D:
	if key == "":
		return Transform2D.IDENTITY
	var centre := Vector2(1032, 372) if key in ["finished", "failed"] else Vector2(640, 360)
	var amount := lerpf(.965, 1.0, smoothstep(0, 1, progress()))
	return Transform2D(0, Vector2.ONE * amount, 0, centre * (1 - amount))


func close(next: String, action: Callable) -> void:
	advance(next, 0, false)
	if closing:
		return
	close_from = progress()
	close_age = 0
	closing = true
	completion = action
