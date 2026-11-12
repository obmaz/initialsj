extends RefCounted
# 저장된 지역 콘텐츠는 강체 변환으로 보존하고 진입 연결부만 별도 GLB로 조립한다.
const DISTANCE_ARRAYS := ["_steep_cache", "curve_marker_distances"]
const SPANS := ["_hills", "_pinch_cache", "skyway_spans"]


static func shift_value(value: Variant, field: String, offset: float) -> Variant:
	if field in ["span", "bridge_span"] and value is Vector2 and value.y > value.x:
		return value + Vector2.ONE * offset
	if field == "distance" and (value is float or value is int):
		return value + offset
	if value is Dictionary:
		var copy: Dictionary = value.duplicate()
		for key in copy:
			copy[key] = shift_value(copy[key], str(key), offset)
		return copy
	if value is Array:
		var copy: Array = value.duplicate()
		for i in range(copy.size()):
			if field in DISTANCE_ARRAYS and (copy[i] is float or copy[i] is int):
				copy[i] += offset
			elif field in SPANS and copy[i] is Vector2:
				copy[i] += Vector2.ONE * offset
			else:
				copy[i] = shift_value(copy[i], "", offset)
		return copy
	return value


static func shift_node(node: Node, source_root: Node, offset: float) -> void:
	if offset <= 0:
		return
	for key in [&"scene_state", &"ad_record"]:
		if not node.has_meta(key):
			continue
		var state: Dictionary = shift_value(node.get_meta(key), "", offset)
		if node == source_root and key == &"scene_state":
			state.length += offset
			node.set_meta(key, state)
		else:
			node.set_meta(key, state)
