extends StaticBody3D
# 주행 장애물 전용 층. 가드레일과 달리 충격으로 파손되고 무적 차량은 통과한다.
var broken := false
var batch: MultiMeshInstance3D
var slot := -1


func receive_debris_hit() -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	visible = false
	if is_instance_valid(batch) and slot >= 0:
		batch.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))


func reset_debris() -> void:
	broken = false
	visible = true
	collision_layer = 0
