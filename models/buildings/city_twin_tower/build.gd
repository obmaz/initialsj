extends RefCounted


# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"position": Vector3(0, height * .09, 0), "size": Vector3(width, height * .18, depth)})
	for side in [-1.0, 1.0]:
		out.append(
			{
				"position": Vector3(side * width * .29, height * .59, 0),
				"size": Vector3(width * .38, height * .82, depth * .72)
			}
		)
	return out
