extends Node3D

const Features = preload("res://scripts/track/road_features.gd")
const Scenery = preload("res://scripts/environment/road_biome.gd")
const Library = preload("res://scripts/track/route_library.gd")
const ASPHALT = preload("res://assets/environment/asphalt.png")
const ASPHALT_SHADER = preload("res://shaders/asphalt.gdshader")
const PAINT_SHADER = preload("res://shaders/road_paint.gdshader")
const SKID_SHADER = preload("res://shaders/skid_marks.gdshader")
# Height bias, first-ridge strength, first-ridge end and second-ridge start.
# Both overlapping raised-cosine ridges finish before the checkpoint approach.
const TOUR_ELEVATION := {
	"hawaii": Vector4(0, 0.82, 0.54, 0.32),
	"jungle": Vector4(1, 0.86, 0.58, 0.39),
	"city": Vector4(-2, 0.68, 0.48, 0.32),
	"pyramid": Vector4(2, 0.75, 0.55, 0.36),
	"amusement": Vector4(-1, 0.92, 0.50, 0.35),
	"jeju": Vector4(1, 0.78, 0.57, 0.38),
	"ruins": Vector4(3, 0.72, 0.51, 0.35),
	"seoul": Vector4(-2, 0.68, 0.48, 0.32),
	"fuji": Vector4(4, 0.90, 0.55, 0.39),
	"neon": Vector4(-1, 0.76, 0.46, 0.33),
	"canyon": Vector4(4, 0.88, 0.58, 0.36),
	"harbor": Vector4(-2, 0.68, 0.48, 0.33),
	"bamboo": Vector4(2, 0.94, 0.50, 0.35),
	"snow": Vector4(2, 0.86, 0.56, 0.38),
	"volcano": Vector4(4, 0.95, 0.54, 0.37)
}
var features: Array[Dictionary] = []
var skyway_spans: Array[Vector2] = []
var closed_loop := false
var course_id := 0
var bank_samples := PackedFloat32Array()
var runoff_samples := PackedVector2Array()
var bridge_span := Vector2.ZERO
var bridge_lower_distance := 0.0
var bridge_upper_distance := 0.0
@export var region_metadata: Dictionary = {}
var scenery: Node3D
var road_surface: MeshInstance3D
var rockfall: Node3D
var speedway_board: Node3D
var collapse: Node3D
var skid_meshes: Array[MeshInstance3D] = []
var prop_batches: Array[MultiMeshInstance3D] = []
var curve_marker_distances: Array[float] = []
var curve_marker_tunnel: Array[bool] = []
var curve_marker_transforms: Array[Transform3D] = []
var curve_markers: MultiMeshInstance3D
var curve := Curve3D.new()
# 배치 전 곡선을 샘플링해 먼 월드 좌표에서 누적되는 베이크 거리 오차를 피한다.
var sampling_curve: Curve3D
var sampling_transform := Transform3D.IDENTITY
var length := 0.0
var rng := RandomNumberGenerator.new()

var stage := 0
var route_node := 0
var entry_side := 0
var start_heading := -PI / 2
var tour_underpass := Vector2.ZERO
var start_point := Vector3(0, 6, 0)
var surface_lift := 0.0
var entry_buffer_length := 0.0
var entry_content_transform := Transform3D.IDENTITY
var entry_scene_path := ""
var entry_surface: MeshInstance3D


func excavation_depth(distance: float) -> float:
	if not closed_loop or course_id != 0:
		return 0
	var d := fposmod(distance, length)
	var start := underpass_span().x
	return 6.5 * smoothstep(start - 190, start + 12, d) * (1 - smoothstep(start + 228, start + 430, d))


func ground_height(distance: float) -> float:
	return point(distance).y + excavation_depth(distance)


var elevation_benches := {}


func tour_elevation(distance: float, span: float) -> float:
	var height := elevated_base(distance, span) - jungle_cut_depth(distance)
	for steep in steep_starts():
		var blend := (
			smoothstep(steep - 160, steep - 20, distance) * (1 - smoothstep(steep + 165, steep + 525, distance))
		)
		if blend <= 0:
			continue
		if not elevation_benches.has(steep):
			elevation_benches[steep] = elevated_base(steep + 70, span) - jungle_cut_depth(steep + 70)
		height = lerpf(height, elevation_benches[steep], blend)
	return height + steep_lift(distance)


func elevated_base(distance: float, span: float) -> float:
	var height := ridge_height(distance, span)
	var profile: Vector4 = TOUR_ELEVATION[Library.theme(stage, route_node)]
	var first_center := 180 + (span - Library.CHECKPOINT_RUNUP - 260) * profile.z * .5
	if not steep_starts().is_empty():
		first_center = minf(first_center, steep_starts()[0] - 210)
	var first_terrace := (
		smoothstep(first_center - 400, first_center - 220, distance)
		* (1 - smoothstep(first_center + 220, first_center + 400, distance))
	)
	if not elevation_benches.has("first_terrace"):
		elevation_benches["first_terrace"] = ridge_height(first_center, span)
	height = lerpf(height, elevation_benches["first_terrace"], first_terrace)
	# 능선 사이의 넓은 평탄부는 점프의 진입·착지와 잠깐의 휴식 구간을 제공한다.
	var center := span * .74
	var terrace := (
		smoothstep(center - 400, center - 160, distance) * (1 - smoothstep(center + 160, center + 400, distance))
	)
	if not elevation_benches.has("terrace"):
		elevation_benches["terrace"] = ridge_height(center, span)
	return lerpf(height, elevation_benches["terrace"], terrace)


func ridge_height(distance: float, span: float) -> float:
	var u := clampf((distance - 180) / (span - Library.CHECKPOINT_RUNUP - 260), 0, 1)
	var profile: Vector4 = TOUR_ELEVATION[Library.theme(stage, route_node)]
	var first := sin(PI * clampf(u / profile.z, 0, 1))
	var second := sin(PI * clampf((u - profile.w) / (1 - profile.w), 0, 1))
	var extra := 0.0
	for hill in hill_spans():
		var t := clampf((distance - hill.x) / (hill.y - hill.x), 0, 1)
		extra += (25.0 + stage * 2.0) * pow(sin(PI * t), 2)
	# 기존 급경사 주변에서는 부드럽게 물러나 전용 점프의 진입·착지 경사를 보존한다.
	for steep in steep_starts():
		extra *= (
			1.0 - smoothstep(steep - 200, steep - 40, distance) * (1 - smoothstep(steep + 230, steep + 390, distance))
		)
	return (65 + stage * 6 + route_node * 3 + profile.x) * (profile.y * first * first + second * second) + extra


func jungle_cut_depth(distance: float) -> float:
	if closed_loop or Library.theme(stage, route_node) != "jungle":
		return 0
	var tunnel := Library.tunnel_span(stage, route_node)
	return (
		30
		* smoothstep(tunnel.x - 300, tunnel.x + 80, distance)
		* (1 - smoothstep(tunnel.y - 60, tunnel.y + 300, distance))
	)


var _hills_ready := false
var _hills: Array[Vector2] = []


func hill_spans() -> Array[Vector2]:
	if _hills_ready:
		return _hills
	_hills_ready = true
	if closed_loop:
		return _hills
	var span := Library.section_length(stage, route_node)
	for candidate in range(8):
		if _hills.size() >= (1 if stage >= 3 else 2):
			break
		var center: float = span * (.18 + candidate * .09)
		var a: float = center - 250
		var b: float = center + 250
		if not _tour_span_free(a, b):
			continue
		if bridge_span.y > bridge_span.x and a < bridge_span.y + 100 and b > bridge_span.x - 100:
			continue
		if stage == 0 and a < 1480 and b > 750:
			continue
		var conflict := false
		for steep in steep_starts():
			if center < steep + 310 and center > steep - 120:
				conflict = true
		for existing in _hills:
			if a < existing.y + 60 and b > existing.x - 60:
				conflict = true
		if not conflict:
			_hills.append(Vector2(a, b))
	return _hills


# Tour gimmick spans are fixed per stage and route, away from the tunnel. They are cached
# because the road width and height are sampled constantly.
var _steep_cache: Array[float] = []
var _pinch_cache: Array[Vector2] = []
var _gimmicks_ready := false


func _tour_span_free(start: float, finish: float) -> bool:
	var tunnel := Library.tunnel_span(stage, route_node)
	if tunnel.y > tunnel.x and start < tunnel.y + 80 and finish > tunnel.x - 80:
		return false
	return start > 420 and finish < Library.section_length(stage, route_node) - Library.CHECKPOINT_RUNUP - 330


func _prepare_gimmicks() -> void:
	_gimmicks_ready = true
	if closed_loop:
		return
	var span := Library.section_length(stage, route_node)
	var usable := span - Library.CHECKPOINT_RUNUP - 900
	# Steep climbs: up the slope over 90 m, then a sharp drop over 45 m behind the crest.
	var fractions := [0.20] if stage == 0 else ([0.20, 0.72] if stage < 3 else [0.20, 0.50, 0.80])
	for fraction in fractions:
		var start: float = 450 + usable * fraction
		if not _tour_span_free(start - 40, start + 260):
			var tunnel := Library.tunnel_span(stage, route_node)
			start = tunnel.y + 120 if tunnel.y > tunnel.x else start
		var crowded := false
		for other in _steep_cache:
			if absf(other - start) < 450:
				crowded = true
		if not crowded and _tour_span_free(start - 40, start + 260):
			_steep_cache.append(start)
	# Sudden narrowing: the road pinches in over 45 m and holds for 110 m.
	var pinch_fractions := [0.38] if stage == 0 else ([0.38, 0.62] if stage < 3 else [0.34, 0.58, 0.88])
	for fraction in pinch_fractions:
		var start: float = 450 + usable * fraction
		if not _tour_span_free(start - 60, start + 240):
			continue
		var blocked := false
		for s in _steep_cache:
			if start < s + 300 and start + 240 > s - 80:
				blocked = true
		if not blocked:
			_pinch_cache.append(Vector2(start, start + 110))


func steep_starts() -> Array[float]:
	if not _gimmicks_ready:
		_prepare_gimmicks()
	return _steep_cache


func pinch_spans() -> Array[Vector2]:
	if not _gimmicks_ready:
		_prepare_gimmicks()
	return _pinch_cache


func steep_lift(distance: float) -> float:
	var lift := 0.0
	var height := 7.0 + stage * 0.9
	for start in steep_starts():
		lift += height * (smoothstep(start, start + 90, distance) - smoothstep(start + 90, start + 145, distance))
	return lift


# 0 on an ordinary road, 1 while the road is pinched.
func pinch_amount(distance: float) -> float:
	var amount := 0.0
	for span in pinch_spans():
		amount = maxf(
			amount, smoothstep(span.x - 60, span.x, distance) * (1 - smoothstep(span.y, span.y + 70, distance))
		)
	return amount


func _init(
	origin: Vector3 = Vector3(0, 6, 0),
	heading_angle: float = -PI / 2,
	stage_index: int = -1,
	node_index: int = 0,
	side: int = 0
) -> void:
	stage = maxi(0, stage_index)
	route_node = node_index
	entry_side = side
	start_point = origin
	start_heading = heading_angle
	surface_lift = 0.004 if side > 0 else 0.0
	curve.up_vector_enabled = false
	curve.bake_interval = 2
	# PackedScene은 인자 없이 만든 뒤 저장 속성을 복원한다. 이때 기본 지역을 중복 로드하지 않는다.
	# 트리 밖에서 곡선이 필요한 생성자는 단계를 지정하고, 나머지는 _ready()에서 읽는다.
	if stage_index >= 0:
		preload("res://scripts/rendering/world_assets.gd").profile(self)


func point(distance: float, lane: float = 0) -> Vector3:
	var d := fposmod(distance, length) if closed_loop else clampf(distance, 0, length)
	var source: Curve3D = sampling_curve if sampling_curve != null else curve
	var p := source.sample_baked(d, false)
	var a := source.sample_baked(fposmod(d - 2, length) if closed_loop else clampf(d - 2, 0, length), false)
	var b := source.sample_baked(fposmod(d + 2, length) if closed_loop else clampf(d + 2, 0, length), false)
	var forward := (b - a).normalized()
	if distance != d and not closed_loop:
		p += forward * (distance - d)
	var bank := bank_at(d)
	# Speedway camber lifts its inner edge above the infield; Fuji rolls about
	# its centreline so the elevated crossing has a consistent deck height.
	var bank_lane := clampf(lane, -half_width(d), half_width(d)) if closed_loop and course_id == 1 else lane
	var bank_height := bank_lane * tan(bank)
	if closed_loop and course_id == 1:
		bank_height += half_width(d) * absf(tan(bank))
	return sampling_transform * (p + Vector3(-forward.z, 0, forward.x).normalized() * lane + Vector3.UP * bank_height)


func bank_at(distance: float) -> float:
	if bank_samples.is_empty():
		return 0
	var sample := fposmod(distance, length) / length * (bank_samples.size() - 1)
	var index := mini(int(sample), bank_samples.size() - 2)
	return lerpf(bank_samples[index], bank_samples[index + 1], sample - index)


# Authored (t, half width) keys. Each pair of keys is joined with a smoothstep, so the road
# swells into wide passing zones and pinches into narrow technical ones without kinks.
const FUJI_WIDTH := [
	Vector2(0, 10.8),
	Vector2(0.08, 12.0),
	Vector2(0.16, 9.0),
	Vector2(0.22, 7.0),
	Vector2(0.31, 7.0),
	Vector2(0.37, 10.8),
	Vector2(0.42, 8.0),
	Vector2(0.45, 9.4),
	Vector2(0.51, 9.4),
	Vector2(0.56, 11.6),
	Vector2(0.62, 7.4),
	Vector2(0.665, 9.6),
	Vector2(0.79, 9.6),
	Vector2(0.85, 7.2),
	Vector2(0.92, 11.6),
	Vector2(1, 10.8)
]
# The pit lane and its apron sit at the start of the oval, so the road keeps its width there.
const SUNCOAST_WIDTH := [
	Vector2(0, 14.5),
	Vector2(0.13, 14.5),
	Vector2(0.22, 12.4),
	Vector2(0.34, 16.4),
	Vector2(0.46, 13.0),
	Vector2(0.55, 12.2),
	Vector2(0.68, 16.6),
	Vector2(0.75, 14.5),
	Vector2(0.84, 14.5),
	Vector2(0.90, 15.8),
	Vector2(1, 14.5)
]


static func width_profile(keys: Array, t: float) -> float:
	t = clampf(t, 0, 1)
	for i in range(keys.size() - 1):
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if t <= b.x:
			return lerpf(a.y, b.y, smoothstep(a.x, b.x, t))
	return (keys[keys.size() - 1] as Vector2).y


# Roads are drawn and driven narrower than their authored profile: Tour 10%, Fuji 28%, Suncoast
# 37% (the authored numbers below are the original widths).
const WIDTH_SCALE := 0.9
const FUJI_SCALE := 0.72
const SUNCOAST_SCALE := 0.63

# MIDNIGHT HARBOR keeps its authored width: wider on the straights and hairpin apexes (room to
# slide), tighter through the linked bends.
const NIGHT_WIDTH := [
	Vector2(0, 8.4),
	Vector2(0.09, 8.4),
	Vector2(0.11, 7.4),
	Vector2(0.21, 7.4),
	Vector2(0.26, 8.0),
	Vector2(0.31, 8.0),
	Vector2(0.35, 7.2),
	Vector2(0.40, 7.2),
	Vector2(0.43, 8.2),
	Vector2(0.48, 8.2),
	Vector2(0.53, 7.0),
	Vector2(0.62, 8.8),
	Vector2(0.66, 8.8),
	Vector2(0.67, 7.8),
	Vector2(0.72, 8.2),
	Vector2(0.78, 8.2),
	Vector2(0.80, 7.6),
	Vector2(0.86, 8.2),
	Vector2(0.89, 7.4),
	Vector2(0.97, 8.4),
	Vector2(1, 8.4)
]


func width_scale() -> float:
	if closed_loop and course_id in [2, 3, 4]:
		return 1.0
	if closed_loop and course_id == 0:
		return FUJI_SCALE
	if closed_loop and course_id == 1:
		return SUNCOAST_SCALE
	return WIDTH_SCALE


func half_width(distance: float) -> float:
	var width := authored_half_width(distance) * width_scale()
	if not closed_loop:
		for span in skyway_spans:
			var blend := (
				smoothstep(span.x - 100, span.x - 20, distance) * (1 - smoothstep(span.y + 20, span.y + 100, distance))
			)
			width = lerpf(width, maxf(width, 11.5), blend)
	return width


# 기믹 배치가 확정된 뒤 한 번 저장한다. 폭 샘플마다 전체 기믹 목록을 훑지 않는다.
func configure_skyways(decks: Array) -> void:
	skyway_spans.clear()
	for deck in decks:
		skyway_spans.append(Vector2(deck.distance - deck.length * .5, deck.distance + deck.length * .5))


func authored_half_width(distance: float) -> float:
	if closed_loop and course_id == 1:
		return width_profile(SUNCOAST_WIDTH, fposmod(distance, length) / length)
	if closed_loop and course_id == 2:
		var d := fposmod(distance, length)
		var corridor = preload("res://scripts/track/harbor_corridor.gd")
		return lerpf(width_profile(NIGHT_WIDTH, d / length), corridor.HALF_WIDTH, corridor.weight(d))
	if closed_loop and course_id == 4:
		return 11.6 + 1.0 * pow(sin(TAU * fposmod(distance, length) / length), 2)
	if closed_loop and course_id == 3:
		return preload("res://scripts/track/riviera_profile.gd").half_width(distance, length)
	if closed_loop:
		return width_profile(FUJI_WIDTH, fposmod(distance, length) / length)
	var content_distance := maxf(0, distance - entry_buffer_length)
	var t := clampf(content_distance / maxf(1, length - entry_buffer_length), 0, 1)
	var blend := smoothstep(180, 360, content_distance) * (1 - smoothstep(length - 360, length - 180, distance))
	# Saturated sine: long wide and narrow stretches joined by quick but smooth transitions.
	var wave := tanh(1.7 * sin(TAU * (2.4 + route_node * 0.2) * t + stage * 1.3))
	var tunnel := Library.tunnel_span(stage, route_node)
	if tunnel.y > tunnel.x:
		wave *= (
			1
			- (
				smoothstep(tunnel.x - 120, tunnel.x - 30, distance)
				* (1 - smoothstep(tunnel.y + 30, tunnel.y + 120, distance))
				* 0.7
			)
		)
	var width := 9.6 - route_node * 0.4 + 3.0 * wave
	var pinch := pinch_amount(distance)
	width = lerpf(width, 5.6, pinch)
	return lerpf(9.0, clampf(width, 5.6, 12.6), blend)


func rail_setback(distance: float, side: float) -> float:
	if closed_loop and course_id >= 1:
		if runoff_samples.is_empty():
			runoff_samples = preload("res://scripts/track/circuit_runoff.gd").build(self)
		var u := fposmod(distance, length) / length * (runoff_samples.size() - 1)
		var index := floori(u)
		return runoff_samples[index].lerp(runoff_samples[index + 1], u - index)[0 if side < 0 else 1]
	var d := fposmod(distance, length) if closed_loop else clampf(distance, 0, length)
	if excavation_depth(d) > 0.05:
		return 1.5
	var t := maxf(0, d - entry_buffer_length) / maxf(1, length - entry_buffer_length)
	var first := smoothstep(0.15, 0.20, t) * (1 - smoothstep(0.30, 0.35, t))
	var second := smoothstep(0.40, 0.45, t) * (1 - smoothstep(0.60, 0.65, t))
	if closed_loop:
		first = smoothstep(0.06, 0.10, t) * (1 - smoothstep(0.17, 0.22, t))
		second = smoothstep(0.73, 0.77, t) * (1 - smoothstep(0.86, 0.91, t))
	else:
		if d < 260 + entry_buffer_length or d > length - 850:
			return 1.5
		var tunnel := Library.tunnel_span(stage, route_node)
		if tunnel.y > tunnel.x:
			var shelter := (
				smoothstep(tunnel.x - 100, tunnel.x - 30, d) * (1 - smoothstep(tunnel.y + 30, tunnel.y + 100, d))
			)
			first *= 1 - shelter
			second *= 1 - shelter
	var width := first * (5.0 if side > 0 else 2.8) + second * (2.5 if side > 0 else 4.0)
	if not closed_loop and bridge_span.y > bridge_span.x:
		var deck := (
			smoothstep(bridge_span.x - 100, bridge_span.x - 30, d)
			* (1 - smoothstep(bridge_span.y + 30, bridge_span.y + 100, d))
		)
		width *= 1 - deck
	if closed_loop and course_id == 0 and bridge_span.y > bridge_span.x:
		var viaduct := (
			smoothstep(bridge_span.x - 90, bridge_span.x, d) * (1 - smoothstep(bridge_span.y, bridge_span.y + 90, d))
		)
		width *= 1 - viaduct
	return 1.5 + width * (1.0 if closed_loop else (1.0 - route_node * 0.10))


func speedway_pit_wall(distance: float) -> bool:
	var d := fposmod(distance, length)
	return closed_loop and course_id == 1 and (d <= 930 or d >= length - 260)


func roadside_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = scenery.terrain_point(distance, lane)
	if course_id >= 1 or in_tunnel(distance) or excavation_depth(distance) > 0.05:
		return p
	var side := signf(lane)
	var flat_edge := half_width(distance) + rail_setback(distance, side) + 1.3
	var span := shoulder_bank_span(distance, side)
	if absf(lane) <= flat_edge + span:
		var far: Vector3 = scenery.terrain_point(distance, side * (flat_edge + span))
		p.y = maxf(p.y, lerpf(point(distance).y - 0.025, far.y, clampf((absf(lane) - flat_edge) / span, 0, 1)))
	return p


func shoulder_bank_span(distance: float, side: float) -> float:
	if closed_loop and course_id == 0 and side < 0:
		# Broad natural lakeside slopes; tight hairpins cannot fold a bank across
		# the centre of their own curve. Steep constrained parts use rock shading.
		return clampf(0.35 / maxf(absf(curvature(distance)), 0.0001), 12, 80)
	return 8.0


func surface_lane(reference: float, distance: float) -> float:
	return (
		reference * half_width(distance) / 9
		if absf(reference) <= 9
		else signf(reference) * (half_width(distance) + absf(reference) - 9)
	)


func underpass_span() -> Vector2:
	return Vector2(length * 0.46, length * 0.46 + 240) if closed_loop and course_id == 0 else Vector2.ZERO


func on_bridge(distance: float) -> bool:
	if bridge_span.y <= bridge_span.x or (closed_loop and course_id not in [0, 4]):
		return false
	var d := fposmod(distance, length) if closed_loop else distance
	return d >= bridge_span.x and d <= bridge_span.y


func in_tunnel(distance: float) -> bool:
	if (
		not closed_loop
		and tour_underpass.y > tour_underpass.x
		and distance >= tour_underpass.x
		and distance <= tour_underpass.y
	):
		return true
	if course_id >= 1:
		return false
	if closed_loop:
		var d := fposmod(distance, length)
		var span := underpass_span()
		return d >= span.x and d <= span.y
	var span := Library.tunnel_span(stage, route_node)
	return span.y > span.x and distance >= span.x and distance <= span.y


func heading(distance: float) -> float:
	var f := point(distance + 2) - point(distance - 2)
	return atan2(-f.x, -f.z)


func curvature(distance: float) -> float:
	return wrapf(heading(distance + 12) - heading(distance - 12), -PI, PI) / 24


func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.65 if metallic == 0 else 0.28
	return m


func paint(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	mat.set_shader_parameter("paint_color", color)
	mat.set_shader_parameter("harbor_corridor", closed_loop and course_id == 2)
	return mat


# staged 구간은 GLB 읽기·씬 연결을 쌓고 Track이 프레임마다 예산 안에서 실행한다.
var staged := false
var draining := false
var warmed: Array[String] = []
var asset_paths: Array[String] = []
var profile_path := ""
var asset_context: Dictionary = {}
var build_queue: Array[Callable] = []


func build_pending() -> bool:
	return not build_queue.is_empty()


# budget_usec < 0이면 남은 단계를 모두 실행한다. 완료되면 true.
func build_some(budget_usec: int = -1) -> bool:
	if budget_usec >= 0 and not preload("res://scripts/rendering/world_assets.gd").available(self):
		return false
	var started := Time.get_ticks_usec()
	var completed := 0
	draining = true
	while not build_queue.is_empty():
		var step: Callable = build_queue.pop_front()
		step.call()
		completed += 1
		if budget_usec >= 0 and (Time.get_ticks_usec() - started >= budget_usec or completed >= 3):
			break
	draining = false
	if build_queue.is_empty():
		staged = false
	return build_queue.is_empty()


# 실행 중인 단계의 하위 작업을 다음 순서에 끼워 넣는다. 즉시 생성 구간은 남은 작업을 모두 실행한다.
func queue_next(steps: Array[Callable]) -> void:
	for i in range(steps.size() - 1, -1, -1):
		build_queue.push_front(steps[i])
	if not staged and not draining:
		build_some()


func _ready() -> void:
	if preload("res://models/shared/scene_state.gd").bind(self):
		return
	if region_metadata.is_empty():
		region_metadata = preload("res://scripts/environment/tour_region_metadata.gd").resolve(
			Library.theme(stage, route_node)
		)
	var assets := preload("res://scripts/rendering/world_assets.gd")
	if profile_path != assets.folder(self):
		assets.profile(self)
	build_queue.append(func(): preload("res://scripts/rendering/world_assets.gd").queue(self))
	if not staged:
		build_some()


func checkpoint_distance() -> float:
	return maxf(80, length - Library.CHECKPOINT_RUNUP)


func _exit_tree() -> void:
	preload("res://scripts/rendering/world_assets.gd").cancel(self)
