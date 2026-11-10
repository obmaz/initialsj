extends RefCounted
# 미터 단위 외곽 안에서 서로 다른 12종의 건물 덩어리를 조립한다.
static func parts(style: int, width: float, height: float, depth: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match style:
		2,6:
			var tiers := 3 if style == 2 else 5
			var base := 0.0
			for i in range(tiers):
				var h := height*(.5 if i == 0 else .25) if style == 2 else height*(.36 if i == 0 else .16)
				out.append({"position":Vector3(0,base+h*.5,0),"size":Vector3(width*(1-i*.16),h,depth*(1-i*.16))})
				base += h
		7:
			out.append({"position":Vector3(0,height*.09,0),"size":Vector3(width,height*.18,depth)})
			for side in [-1.0,1.0]: out.append({"position":Vector3(side*width*.29,height*.59,0),"size":Vector3(width*.38,height*.82,depth*.72)})
		8:
			out.append({"position":Vector3(0,height*.38,0),"size":Vector3(width,height*.76,depth)})
			out.append({"position":Vector3(0,height*.88,0),"size":Vector3(width*.65,height*.24,depth*.65)})
		9:
			out.append({"position":Vector3(-width*.3,height*.5,0),"size":Vector3(width*.4,height,depth)})
			out.append({"position":Vector3(width*.2,height*.32,depth*.25),"size":Vector3(width*.6,height*.64,depth*.5)})
		5:
			out.append({"position":Vector3(0,height*.44,0),"size":Vector3(width,height*.88,depth)})
			out.append({"position":Vector3(0,height*.94,0),"size":Vector3(width*.74,height*.12,depth*.7)})
		10:
			out.append({"position":Vector3(0,height*.38,0),"size":Vector3(width,height*.76,depth)})
			out.append({"position":Vector3(0,height*.88,-depth*.1),"size":Vector3(width*.42,height*.24,depth*.8)})
			for side in [-1.0,1.0]: out.append({"position":Vector3(side*width*.4,height*.81,depth*.05),"size":Vector3(width*.2,height*.1,depth*.7)})
		11:
			for i in range(4): out.append({"position":Vector3((-.08 if i%2 else .08)*width,height*(i+.5)/4,0),"size":Vector3(width*.84,height*.25,depth*(1-i*.08))})
		_:
			out.append({"position":Vector3(0,height*.5,0),"size":Vector3(width,height,depth)})
	if style in [0,4,5,10]:
		var floors := 3 if style in [0,5,10] else 5
		for i in range(1,floors+1):
			out.append({"position":Vector3(0,height*i/floors,depth*.02),"size":Vector3(width, .35 if style != 4 else .65,depth)})
	return out
