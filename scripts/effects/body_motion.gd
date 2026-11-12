extends RefCounted
# 차체의 시각 피벗만 움직인다. 힘은 실제 속도 차분을 차량 축으로 투영해 구하며,
# 접지 전환·순간이동의 속도 차이는 서스펜션 힘으로 사용하지 않는다.
const PROFILES := {
	"hatch": Vector4(15.0, .78, .0025, .0032),
	"wedge": Vector4(20.0, .88, .0016, .0021),
	"muscle": Vector4(11.5, .72, .0032, .0040),
	"gt": Vector4(17.0, .84, .0021, .0027),
}
var pose := Vector3.ZERO
var spring_velocity := Vector3.ZERO
var acceleration := Vector2.ZERO
var previous_velocity := Vector3.ZERO
var sampled := false
var was_grounded := false


func reset() -> void:
	pose = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	acceleration = Vector2.ZERO
	previous_velocity = Vector3.ZERO
	sampled = false
	was_grounded = false


func sample(delta: float, velocity: Vector3, basis: Basis, grounded: bool) -> void:
	if delta <= 0:
		return
	var force := Vector2.ZERO
	if sampled and grounded and was_grounded:
		var change := (velocity - previous_velocity) / delta
		force = Vector2(change.dot(-basis.z), change.dot(basis.x)).clamp(Vector2(-32, -24), Vector2(32, 24))
	acceleration = acceleration.lerp(force, 1 - exp(-delta * 12))
	previous_velocity = velocity
	was_grounded = grounded
	sampled = true


func land(strength: float) -> void:
	# y가 아래로 눌린 뒤 감쇠하며 한 번 작게 되돌아온다. 수직 물리 속도와 무관하다.
	spring_velocity.y -= clampf(strength, 0, 1) * 1.5


func advance(delta: float, model: String, reduced: bool, shift: float = 0.0) -> void:
	var profile: Vector4 = PROFILES.get(model, PROFILES.hatch)
	var scale := .25 if reduced else 1.0
	var target := (
		Vector3(
			clampf(acceleration.x * profile.z - shift * .012, -.075, .075),
			0,
			clampf(acceleration.y * profile.w, -.085, .085)
		)
		* scale
	)
	# 짧은 고정 서브스텝으로 렌더 프레임이 늦어져도 스프링이 발산하지 않는다.
	var remaining := minf(delta, .1)
	while remaining > 0:
		var dt := minf(remaining, 1.0 / 120)
		spring_velocity += ((target - pose) * profile.x * profile.x - spring_velocity * 2 * profile.x * profile.y) * dt
		pose += spring_velocity * dt
		remaining -= dt
	pose.y = clampf(pose.y, -.065 if reduced else -.13, .035 if reduced else .07)
