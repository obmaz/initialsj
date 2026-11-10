extends RefCounted
# 이 팩의 형상만 소유하는 순수 파츠 생성 함수.
static func build(_definition: Resource, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"position":Vector3(0,height*.5,0),"size":Vector3(width,height,depth)})
	for i in range(1,5+1):
		out.append({"position":Vector3(0,height*i/5,depth*.02),"size":Vector3(width, .65,depth)})
	return out
