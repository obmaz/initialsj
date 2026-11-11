extends Node3D
# 도로 양옆의 층상 절벽을 잇는 두꺼운 자연 암석 아치. 차선 위 유효 높이를 비운다.
var track: Node3D
var distances: Array[float] = [1140.0, 2380.0]
var manifest: Array[Dictionary] = []
var falls: Array[Dictionary] = []
var shared_rock_material: ShaderMaterial


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
	for fall in falls:
		for piece in fall.pieces:
			if piece.get_script() == null:
				piece.set_script(preload("res://scripts/physics/road_debris.gd"))


func reset_effect() -> void:
	for fall in falls:
		fall.elapsed = -1.0
		fall.landed = false
		for i in range(fall.pieces.size()):
			if fall.pieces[i].get_script() == null:
				fall.pieces[i].set_script(preload("res://scripts/physics/road_debris.gd"))
			fall.pieces[i].reset_debris()
			fall.pieces[i].position = fall.origins[i]
			fall.pieces[i].rotation = Vector3.ZERO
			fall.pieces[i].collision_layer = 0


func advance(delta: float, distance: float, lap: int) -> void:
	var d := fposmod(distance, track.length)
	for fall in falls:
		if fall.landed:
			continue
		if fall.elapsed < 0:
			if lap < 1 or d < fall.distance - 260 or d > fall.distance + 30:
				continue
			fall.elapsed = 0.0
		fall.elapsed += delta
		var landed := true
		for i in range(fall.pieces.size()):
			if fall.pieces[i].get("broken") == true:
				continue
			var t := clampf((fall.elapsed - .35 - i * .035) / 1.65, 0, 1)
			fall.pieces[i].position = fall.origins[i].lerp(fall.targets[i], t * t)
			fall.pieces[i].rotation.y = sin(i * 2.7) * t * .12
			if t >= 1:
				fall.pieces[i].collision_layer = 8
			else:
				landed = false
		fall.landed = landed


func safe_lane(distance: float, requested: float) -> float:
	var d := fposmod(distance, track.length)
	for fall in falls:
		if fall.elapsed >= 0 and d > fall.distance - 170 and d < fall.distance + 35:
			return (-1.0 if requested < 0 else 1.0) * track.half_width(d) * .65
	return requested


func warning(distance: float) -> String:
	var d := fposmod(distance, track.length)
	for fall in falls:
		if fall.elapsed >= 0 and d > fall.distance - 280 and d < fall.distance + 35:
			return "ARCH COLLAPSE / SIDE LANES SAFE"
	return ""
