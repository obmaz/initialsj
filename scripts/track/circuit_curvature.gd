extends RefCounted
# 닫힌 코스의 수평 곡률만 보관한다. 노면·뱅크·충돌 좌표는 원래 프로필을 사용한다.
const MAX_STEP := .5
var length := 0.0
var spacing := 1.0
var samples := PackedFloat32Array()


func _init(curve: Curve3D, road_length: float) -> void:
	length = road_length
	var count := maxi(1, ceili(length / MAX_STEP))
	spacing = length / count
	samples.resize(count + 1)
	for i in range(count):
		var d := i * spacing
		samples[i] = wrapf(heading(curve, d + 12) - heading(curve, d - 12), -PI, PI) / 24
	samples[count] = samples[0]


func heading(curve: Curve3D, distance: float) -> float:
	var forward := (
		curve.sample_baked(fposmod(distance + 2, length), false)
		- curve.sample_baked(fposmod(distance - 2, length), false)
	)
	return atan2(-forward.x, -forward.z)


func at(distance: float) -> float:
	var u := fposmod(distance, length) / spacing
	var index := mini(floori(u), samples.size() - 2)
	return lerpf(samples[index], samples[index + 1], u - index)
