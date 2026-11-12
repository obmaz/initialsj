extends RefCounted
# 닫힌 코스의 수평 곡률만 보관한다. 노면·뱅크·충돌 좌표는 원래 프로필을 사용한다.
const MAX_SAMPLE_SPACING_M := .5
var track_length_m := 0.0
var sample_spacing_m := 1.0
var curvature_samples := PackedFloat32Array()


func _init(curve: Curve3D, source_length_m: float) -> void:
	track_length_m = source_length_m
	var sample_count := maxi(1, ceili(track_length_m / MAX_SAMPLE_SPACING_M))
	sample_spacing_m = track_length_m / sample_count
	curvature_samples.resize(sample_count + 1)
	for i in range(sample_count):
		var sample_distance_m := i * sample_spacing_m
		curvature_samples[i] = (
			wrapf(heading(curve, sample_distance_m + 12) - heading(curve, sample_distance_m - 12), -PI, PI) / 24
		)
	curvature_samples[sample_count] = curvature_samples[0]


func heading(curve: Curve3D, distance_m: float) -> float:
	var forward := (
		curve.sample_baked(fposmod(distance_m + 2, track_length_m), false)
		- curve.sample_baked(fposmod(distance_m - 2, track_length_m), false)
	)
	return atan2(-forward.x, -forward.z)


func sample_curvature(distance_m: float) -> float:
	var sample_position := fposmod(distance_m, track_length_m) / sample_spacing_m
	var sample_index := mini(floori(sample_position), curvature_samples.size() - 2)
	return lerpf(curvature_samples[sample_index], curvature_samples[sample_index + 1], sample_position - sample_index)
