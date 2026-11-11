extends Node3D
# 접근하는 차량 앞에서 오른쪽 상판이 순차 붕괴한다. 점프와 왼쪽 우회로를 남긴다.
const PIECES := 9
const PIECE_LENGTH := 12.0
var fall_times: Array[float] = []
var broken := false
var wreckage: Node3D
var section: Node3D
var span := Vector2(421, 529)
var lanes := Vector2(2.8, 8.2)
var elapsed := -1.0
var chunks: Array[Node3D] = []
var origins: Array[Vector3] = []
var floors: Array[StaticBody3D] = []
var floor_faces: Array[PackedVector3Array] = []
var cracks: Node3D
var dust: CPUParticles3D


func contains(d: float, reference: float) -> bool:
	return d >= span.x and d <= span.y and reference > lanes.x and reference < lanes.y


func inside_span(d: float) -> bool:
	return d >= span.x and d <= span.y


func reset_effect() -> void:
	elapsed = -1
	broken = false
	for i in range(chunks.size()):
		fall_times[i] = -1
		chunks[i].transform = Transform3D(Basis.IDENTITY, origins[i])
		chunks[i].visible = true
		floors[i].collision_layer = 1
	cracks.visible = false
	wreckage.visible = false
	dust.emitting = false


func advance(delta: float, distance: float, reduced_motion: bool = false) -> void:
	var d := fposmod(distance, section.length)
	if elapsed < 0:
		if d < span.x - 220 or d > span.y + 50:
			return
		elapsed = 0
	elapsed += delta
	cracks.visible = not broken
	for i in range(cracks.get_child_count()):
		cracks.get_child(i).visible = elapsed > (i % 9) * .12
	# 균열 경고 뒤 앞쪽부터 순차 낙하해 접근 중에도 붕괴를 볼 수 있다.
	for i in range(PIECES):
		if fall_times[i] < 0:
			if d < span.x - 140 or elapsed < .65 + i * .09:
				continue
			fall_times[i] = 0
		fall_times[i] += delta
		var t := maxf(0, fall_times[i] - .22)
		if t <= 0:
			continue
		floors[i].collision_layer = 0
		if not broken:
			broken = true
			wreckage.visible = true
			if DisplayServer.get_name() != "headless" and not reduced_motion:
				dust.position = origins[i] + Vector3.UP * .5
				dust.restart()
				dust.emitting = true
		# 부서진 상판을 아래에 남겨 다음 바퀴에도 붕괴 흔적이 보인다.
		chunks[i].position = origins[i] + Vector3(0, -minf(14 + i * .6, 12 * t * t), 0)
		chunks[i].rotation = Vector3(minf(t, .9) * .28 * (i % 3 - 1), 0, minf(t, 1.2) * .45)
		chunks[i].visible = true
	cracks.visible = not broken


func warning(distance: float) -> String:
	var d := fposmod(distance, section.length)
	if d < span.x - 260 or d > span.y + 35:
		return ""
	return "BRIDGE DESTROYED / JUMP OR KEEP LEFT" if broken else "BRIDGE CRACKING / JUMP OR KEEP LEFT"
