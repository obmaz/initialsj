extends RefCounted
# 실제 비행 상태·보상 계측만 보관한다. 중력과 접지는 world_car.gd가 처리한다.
var active := false
var trick := false
var height := 0.0
var world_y := 0.0
var velocity := 0.0
var landing_flash := 0.0
var landing_strength := 0.0
var launches := 0
var landings := 0


func reset() -> void:
	active = false
	trick = false
	height = 0
	world_y = 0
	velocity = 0
	landing_flash = 0
	landing_strength = 0
	launches = 0
	landings = 0
