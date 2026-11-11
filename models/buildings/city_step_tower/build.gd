extends RefCounted


# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var style := 6
	var out: Array[Dictionary] = []
	var tiers := 3 if style == 2 else 5
	var base := 0.0
	for i in range(tiers):
		var h := height * (.5 if i == 0 else .25) if style == 2 else height * (.36 if i == 0 else .16)
		out.append(
			{"position": Vector3(0, base + h * .5, 0), "size": Vector3(width * (1 - i * .16), h, depth * (1 - i * .16))}
		)
		base += h
	return out
