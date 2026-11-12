extends Node
# 지난 구간은 충돌·그룹·처리를 즉시 끄고 자원 해제만 자식부터 여러 프레임에 나눈다.
const BUDGET_USEC := 500
const NODE_LIMIT := 12
var pending: Array[Node] = []


func schedule(source: Node) -> void:
	if source.get_meta("retirement_pending", false):
		return
	source.set_meta("retirement_pending", true)
	if source is Node3D:
		source.visible = false
	source.process_mode = Node.PROCESS_MODE_DISABLED
	collect(source)


func collect(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for group in node.get_groups():
		node.remove_from_group(group)
	# 자식 CollisionShape3D가 각 형상을 보유하므로 마지막 큰 묶음 해제를 피한다.
	if node.has_meta("collision_data"):
		node.remove_meta("collision_data")
	pending.append(node)
	for child in node.get_children():
		collect(child)


func drain(budget_usec: int = BUDGET_USEC) -> int:
	var started := Time.get_ticks_usec()
	var count := 0
	while not pending.is_empty():
		var node = pending.pop_back()
		if is_instance_valid(node):
			node.free()
		count += 1
		if count >= NODE_LIMIT or Time.get_ticks_usec() - started >= budget_usec:
			break
	return count


func _process(_delta: float) -> void:
	drain()
	if pending.is_empty():
		queue_free()


func _exit_tree() -> void:
	pending.clear()
