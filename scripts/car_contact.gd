extends RefCounted
const HALF_WIDTH := 1.1
const HALF_LENGTH := 2.2
# Separating-axis test for oriented car footprints in road-local X/Z coordinates.
static func overlap(longitudinal: float, lateral: float, yaw_a: float, yaw_b: float) -> Dictionary:
	if absf(longitudinal) > 6 or absf(lateral) > 5: return {}
	var center := Vector2(lateral,-longitudinal)
	var ax := Vector2(cos(yaw_a),-sin(yaw_a))
	var az := Vector2(sin(yaw_a),cos(yaw_a))
	var bx := Vector2(cos(yaw_b),-sin(yaw_b))
	var bz := Vector2(sin(yaw_b),cos(yaw_b))
	var depth := INF
	var normal := Vector2.ZERO
	for axis in [ax,az,bx,bz]:
		var radius_a: float = absf(axis.dot(ax)) * HALF_WIDTH + absf(axis.dot(az)) * HALF_LENGTH
		var radius_b: float = absf(axis.dot(bx)) * HALF_WIDTH + absf(axis.dot(bz)) * HALF_LENGTH
		var penetration: float = radius_a + radius_b - absf(center.dot(axis))
		if penetration <= 0: return {}
		if penetration < depth:
			depth = penetration
			normal = axis * (1 if center.dot(axis) >= 0 else -1)
	return {"normal":normal,"depth":depth}
