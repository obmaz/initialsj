extends RefCounted


# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"position": Vector3(0, height * .38, 0), "size": Vector3(width, height * .76, depth)})
	out.append({"position": Vector3(0, height * .88, 0), "size": Vector3(width * .65, height * .24, depth * .65)})
	return out
