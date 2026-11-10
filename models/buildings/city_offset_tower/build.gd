extends RefCounted
# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(4): out.append({"position":Vector3((-.08 if i%2 else .08)*width,height*(i+.5)/4,0),"size":Vector3(width*.84,height*.25,depth*(1-i*.08))})
	return out
