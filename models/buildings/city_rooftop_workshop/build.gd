extends RefCounted


# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"position": Vector3(0, height * .38, 0), "size": Vector3(width, height * .76, depth)})
	out.append(
		{"position": Vector3(0, height * .88, -depth * .1), "size": Vector3(width * .42, height * .24, depth * .8)}
	)
	for side in [-1.0, 1.0]:
		out.append(
			{
				"position": Vector3(side * width * .4, height * .81, depth * .05),
				"size": Vector3(width * .2, height * .1, depth * .7)
			}
		)
	for i in range(1, 3 + 1):
		out.append({"position": Vector3(0, height * i / 3, depth * .02), "size": Vector3(width, .35, depth)})
	return out
