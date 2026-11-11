extends RefCounted


# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"position": Vector3(-width * .3, height * .5, 0), "size": Vector3(width * .4, height, depth)})
	out.append(
		{
			"position": Vector3(width * .2, height * .32, depth * .25),
			"size": Vector3(width * .6, height * .64, depth * .5)
		}
	)
	return out
