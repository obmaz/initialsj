extends RefCounted
# 씬에 저장한 연결점과 제어 상태를 복원한다. 기하 생성·프레임 처리는 하지 않는다.
const KEY := &"scene_state"


static func decode(value: Variant, root: Node) -> Variant:
	if value is Dictionary:
		if value.has(&"$node"):
			return root.get_node(value[&"$node"])
		if value.has(&"$mesh"):
			return root.get_meta(&"scene_meshes")[value[&"$mesh"]]
		if value.has(&"$rng"):
			var rng := RandomNumberGenerator.new()
			rng.seed = value[&"seed"]
			rng.state = value[&"$rng"]
			return rng
		var result := {}
		for key in value:
			result[key] = decode(value[key], root)
		return result
	if value is Array:
		var result: Array = []
		for child in value:
			result.append(decode(child, root))
		return result
	return value


static func bind(node: Node) -> bool:
	if node.get_meta(&"scene_bound", false):
		return true
	if not node.has_meta(KEY):
		return false
	var root: Node = node
	while not root.has_meta(&"asset_root"):
		root = root.get_parent()
	var state: Dictionary = node.get_meta(KEY)
	for key in state:
		var value: Variant = decode(state[key], root)
		var current: Variant = node.get(key)
		if current is Array:
			current.assign(value)
			node.set(key, current)
		else:
			node.set(key, value)
	node.set_meta(&"scene_bound", true)
	return true
