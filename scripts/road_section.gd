extends Node3D

const Features = preload("res://scripts/road_features.gd")
const Scenery = preload("res://scripts/road_biome.gd")
const Library = preload("res://scripts/route_library.gd")
const ASPHALT = preload("res://assets/environment/asphalt.png")
const ASPHALT_SHADER = preload("res://shaders/asphalt.gdshader")
const PAINT_SHADER = preload("res://shaders/road_paint.gdshader")
const SKID_SHADER = preload("res://shaders/skid_marks.gdshader")
# Height bias, first-ridge strength, first-ridge end and second-ridge start.
# Both overlapping raised-cosine ridges finish before the checkpoint approach.
const TOUR_ELEVATION := {
	"hawaii":Vector4(0,0.82,0.54,0.32),"jungle":Vector4(1,0.86,0.58,0.39),
	"city":Vector4(-2,0.68,0.48,0.32),"pyramid":Vector4(2,0.75,0.55,0.36),
	"amusement":Vector4(-1,0.92,0.50,0.35),"jeju":Vector4(1,0.78,0.57,0.38),
	"ruins":Vector4(3,0.72,0.51,0.35),"seoul":Vector4(-2,0.68,0.48,0.32),
	"fuji":Vector4(4,0.90,0.55,0.39),"neon":Vector4(-1,0.76,0.46,0.33),
	"canyon":Vector4(4,0.88,0.58,0.36),"harbor":Vector4(-2,0.68,0.48,0.33),
	"bamboo":Vector4(2,0.94,0.50,0.35),"snow":Vector4(2,0.86,0.56,0.38),
	"volcano":Vector4(4,0.95,0.54,0.37)
}
var features: Array[Dictionary] = []
var closed_loop := false
var course_id := 0
var bank_samples := PackedFloat32Array()
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
var length := 0.0
var rng := RandomNumberGenerator.new()

var stage := 0
var route_node := 0
var entry_side := 0
var start_heading := -PI / 2
var start_point := Vector3(0,6,0)
var surface_lift := 0.0

func excavation_depth(distance: float) -> float:
	if not closed_loop or course_id != 0: return 0
	var d := fposmod(distance,length)
	var start := underpass_span().x
	return 6.5*smoothstep(start-190,start+12,d)*(1-smoothstep(start+228,start+430,d))

func ground_height(distance: float) -> float:
	return point(distance).y+excavation_depth(distance)

func tour_elevation(distance: float, span: float) -> float:
	var u := clampf((distance-180)/(span-Library.CHECKPOINT_RUNUP-260),0,1)
	var profile: Vector4 = TOUR_ELEVATION[Library.theme(stage,route_node)]
	var first := sin(PI*clampf(u/profile.z,0,1))
	var second := sin(PI*clampf((u-profile.w)/(1-profile.w),0,1))
	var extra := 0.0
	for hill in hill_spans():
		var t := clampf((distance-hill.x)/(hill.y-hill.x),0,1)
		extra += (25.0+stage*2.0)*pow(sin(PI*t),2)
	# 기존 급경사 주변에서는 부드럽게 물러나 전용 점프의 진입·착지 경사를 보존한다.
	for steep in steep_starts():
		extra *= 1.0-smoothstep(steep-200,steep-40,distance)*(1-smoothstep(steep+230,steep+390,distance))
	return (37+stage*4+route_node*2+profile.x)*(profile.y*first*first+second*second)+steep_lift(distance)+extra

var _hills_ready := false
var _hills: Array[Vector2] = []
func hill_spans() -> Array[Vector2]:
	if _hills_ready: return _hills
	_hills_ready = true
	if closed_loop: return _hills
	var span := Library.section_length(stage,route_node)
	for candidate in range(8):
		if _hills.size() >= (1 if stage >= 3 else 2): break
		var center: float = span*(.18+candidate*.09)
		var a: float = center-250
		var b: float = center+250
		if not _tour_span_free(a,b): continue
		if bridge_span.y > bridge_span.x and a < bridge_span.y+100 and b > bridge_span.x-100: continue
		if stage == 0 and a < 1480 and b > 750: continue
		var conflict := false
		for steep in steep_starts():
			if center < steep+310 and center > steep-120: conflict = true
		for existing in _hills:
			if a < existing.y+60 and b > existing.x-60: conflict = true
		if not conflict: _hills.append(Vector2(a,b))
	return _hills

# Tour gimmick spans are fixed per stage and route, away from the tunnel. They are cached
# because the road width and height are sampled constantly.
var _steep_cache: Array[float] = []
var _pinch_cache: Array[Vector2] = []
var _gimmicks_ready := false

func _tour_span_free(start: float, finish: float) -> bool:
	var tunnel := Library.tunnel_span(stage,route_node)
	if tunnel.y > tunnel.x and start < tunnel.y+80 and finish > tunnel.x-80: return false
	return start > 420 and finish < Library.section_length(stage,route_node)-Library.CHECKPOINT_RUNUP-330

func _prepare_gimmicks() -> void:
	_gimmicks_ready = true
	if closed_loop: return
	var span := Library.section_length(stage,route_node)
	var usable := span-Library.CHECKPOINT_RUNUP-900
	# Steep climbs: up the slope over 90 m, then a sharp drop over 45 m behind the crest.
	var fractions := [0.20] if stage == 0 else ([0.20,0.72] if stage < 3 else [0.20,0.50,0.80])
	for fraction in fractions:
		var start: float = 450+usable*fraction
		if not _tour_span_free(start-40,start+260):
			var tunnel := Library.tunnel_span(stage,route_node)
			start = tunnel.y+120 if tunnel.y > tunnel.x else start
		var crowded := false
		for other in _steep_cache:
			if absf(other-start) < 450: crowded = true
		if not crowded and _tour_span_free(start-40,start+260): _steep_cache.append(start)
	# Sudden narrowing: the road pinches in over 45 m and holds for 110 m.
	var pinch_fractions := [0.38] if stage == 0 else ([0.38,0.62] if stage < 3 else [0.34,0.58,0.88])
	for fraction in pinch_fractions:
		var start: float = 450+usable*fraction
		if not _tour_span_free(start-60,start+240): continue
		var blocked := false
		for s in _steep_cache:
			if start < s+300 and start+240 > s-80: blocked = true
		if not blocked: _pinch_cache.append(Vector2(start,start+110))

func steep_starts() -> Array[float]:
	if not _gimmicks_ready: _prepare_gimmicks()
	return _steep_cache

func pinch_spans() -> Array[Vector2]:
	if not _gimmicks_ready: _prepare_gimmicks()
	return _pinch_cache

func steep_lift(distance: float) -> float:
	var lift := 0.0
	var height := 7.0+stage*0.9
	for start in steep_starts():
		lift += height*(smoothstep(start,start+90,distance)-smoothstep(start+90,start+145,distance))
	return lift

# 0 on an ordinary road, 1 while the road is pinched.
func pinch_amount(distance: float) -> float:
	var amount := 0.0
	for span in pinch_spans():
		amount = maxf(amount,smoothstep(span.x-60,span.x,distance)*(1-smoothstep(span.y,span.y+70,distance)))
	return amount

func _init(origin: Vector3 = Vector3(0,6,0), heading_angle: float = -PI / 2, stage_index: int = 0, node_index: int = 0, side: int = 0) -> void:
	stage = stage_index
	route_node = node_index
	entry_side = side
	start_point = origin
	start_heading = heading_angle
	surface_lift = 0.004 if side > 0 else 0.0
	curve.up_vector_enabled = false
	curve.bake_interval = 2
	var p := origin
	var span := Library.section_length(stage,route_node)
	for i in range(int(span/5)+1):
		var d := i * 5.0
		var t := d/span
		var envelope := smoothstep(200,360,d)*(1-smoothstep(span-Library.CHECKPOINT_RUNUP-160,span-Library.CHECKPOINT_RUNUP-20,d))
		var severity := 1.12*(1.0+route_node*0.18)
		var wave := (0.42+stage*0.025)*severity*sin(TAU*(2.0+route_node*0.18)*t)
		wave += (0.14+route_node*0.025)*sin(TAU*(4.0+route_node*0.28)*t)*pow(sin(PI*t),2)
		var angle := start_heading-side*0.38*smoothstep(0,180,d)+wave*envelope
		if i > 0: p += Vector3(-sin(angle),0,-cos(angle))*5
		p.y = origin.y+tour_elevation(d,span)
		curve.add_point(p)
	length = curve.get_baked_length()

func point(distance: float, lane: float = 0) -> Vector3:
	var d := fposmod(distance,length) if closed_loop else clampf(distance,0,length)
	var p := curve.sample_baked(d,false)
	var a := curve.sample_baked(fposmod(d-2,length) if closed_loop else clampf(d-2,0,length),false)
	var b := curve.sample_baked(fposmod(d+2,length) if closed_loop else clampf(d+2,0,length),false)
	var forward := (b-a).normalized()
	if distance != d and not closed_loop: p += forward * (distance-d)
	var bank := bank_at(d)
	# Speedway camber lifts its inner edge above the infield; Fuji rolls about
	# its centreline so the elevated crossing has a consistent deck height.
	var bank_height := lane*tan(bank)
	if closed_loop and course_id == 1: bank_height += half_width(d)*absf(tan(bank))
	return p + Vector3(-forward.z,0,forward.x).normalized() * lane + Vector3.UP*bank_height

func bank_at(distance: float) -> float:
	if bank_samples.is_empty(): return 0
	var sample := fposmod(distance,length)/length*(bank_samples.size()-1)
	var index := mini(int(sample),bank_samples.size()-2)
	return lerpf(bank_samples[index],bank_samples[index+1],sample-index)

# Authored (t, half width) keys. Each pair of keys is joined with a smoothstep, so the road
# swells into wide passing zones and pinches into narrow technical ones without kinks.
const FUJI_WIDTH := [Vector2(0,10.8),Vector2(0.08,12.0),Vector2(0.16,9.0),Vector2(0.22,7.0),Vector2(0.31,7.0),Vector2(0.37,10.8),Vector2(0.42,8.0),Vector2(0.45,9.4),Vector2(0.51,9.4),Vector2(0.56,11.6),Vector2(0.62,7.4),Vector2(0.665,9.6),Vector2(0.79,9.6),Vector2(0.85,7.2),Vector2(0.92,11.6),Vector2(1,10.8)]
# The pit lane and its apron sit at the start of the oval, so the road keeps its width there.
const SUNCOAST_WIDTH := [Vector2(0,14.5),Vector2(0.13,14.5),Vector2(0.22,12.4),Vector2(0.34,16.4),Vector2(0.46,13.0),Vector2(0.55,12.2),Vector2(0.68,16.6),Vector2(0.75,14.5),Vector2(0.84,14.5),Vector2(0.90,15.8),Vector2(1,14.5)]

static func width_profile(keys: Array, t: float) -> float:
	t = clampf(t,0,1)
	for i in range(keys.size()-1):
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i+1]
		if t <= b.x: return lerpf(a.y,b.y,smoothstep(a.x,b.x,t))
	return (keys[keys.size()-1] as Vector2).y

# Roads are drawn and driven narrower than their authored profile: Tour 10%, Fuji 28%, Suncoast
# 37% (the authored numbers below are the original widths).
const WIDTH_SCALE := 0.9
const FUJI_SCALE := 0.72
const SUNCOAST_SCALE := 0.63

# MIDNIGHT HARBOR keeps its authored width: wider on the straights and hairpin apexes (room to
# slide), tighter through the linked bends.
const NIGHT_WIDTH := [Vector2(0,8.4),Vector2(0.09,8.4),Vector2(0.11,7.4),Vector2(0.21,7.4),Vector2(0.26,8.0),Vector2(0.31,8.0),Vector2(0.35,7.2),Vector2(0.40,7.2),Vector2(0.43,8.2),Vector2(0.48,8.2),Vector2(0.53,7.0),Vector2(0.62,8.8),Vector2(0.66,8.8),Vector2(0.67,7.8),Vector2(0.72,8.2),Vector2(0.78,8.2),Vector2(0.80,7.6),Vector2(0.86,8.2),Vector2(0.89,7.4),Vector2(0.97,8.4),Vector2(1,8.4)]

func width_scale() -> float:
	if closed_loop and course_id in [2,3,4]: return 1.0
	if closed_loop and course_id == 0: return FUJI_SCALE
	if closed_loop and course_id == 1: return SUNCOAST_SCALE
	return WIDTH_SCALE

func half_width(distance: float) -> float:
	return authored_half_width(distance)*width_scale()

func authored_half_width(distance: float) -> float:
	if closed_loop and course_id == 1: return width_profile(SUNCOAST_WIDTH,fposmod(distance,length)/length)
	if closed_loop and course_id == 2: return width_profile(NIGHT_WIDTH,fposmod(distance,length)/length)
	if closed_loop and course_id == 4: return 11.6+1.0*pow(sin(TAU*fposmod(distance,length)/length),2)
	if closed_loop and course_id == 3: return preload("res://scripts/riviera_profile.gd").half_width(distance,length)
	if closed_loop: return width_profile(FUJI_WIDTH,fposmod(distance,length)/length)
	var t := clampf(distance/length,0,1)
	var blend := smoothstep(180,360,distance)*(1-smoothstep(length-360,length-180,distance))
	# Saturated sine: long wide and narrow stretches joined by quick but smooth transitions.
	var wave := tanh(1.7*sin(TAU*(2.4+route_node*0.2)*t+stage*1.3))
	var tunnel := Library.tunnel_span(stage,route_node)
	if tunnel.y > tunnel.x:
		wave *= 1-smoothstep(tunnel.x-120,tunnel.x-30,distance)*(1-smoothstep(tunnel.y+30,tunnel.y+120,distance))*0.7
	var width := 9.6-route_node*0.4+3.0*wave
	var pinch := pinch_amount(distance)
	width = lerpf(width,5.6,pinch)
	return lerpf(9.0,clampf(width,5.6,12.6),blend)

func rail_setback(distance: float, side: float) -> float:
	if closed_loop and course_id >= 1: return 1.5
	var d := fposmod(distance,length) if closed_loop else clampf(distance,0,length)
	if excavation_depth(d) > 0.05: return 1.5
	var t := d/length
	var first := smoothstep(0.15,0.20,t)*(1-smoothstep(0.30,0.35,t))
	var second := smoothstep(0.40,0.45,t)*(1-smoothstep(0.60,0.65,t))
	if closed_loop:
		first = smoothstep(0.06,0.10,t)*(1-smoothstep(0.17,0.22,t))
		second = smoothstep(0.73,0.77,t)*(1-smoothstep(0.86,0.91,t))
	else:
		if d < 260 or d > length-850: return 1.5
		var tunnel := Library.tunnel_span(stage,route_node)
		if tunnel.y > tunnel.x:
			var shelter := smoothstep(tunnel.x-100,tunnel.x-30,d)*(1-smoothstep(tunnel.y+30,tunnel.y+100,d))
			first *= 1-shelter
			second *= 1-shelter
	var width := first*(5.0 if side > 0 else 2.8)+second*(2.5 if side > 0 else 4.0)
	if not closed_loop and bridge_span.y > bridge_span.x:
		var deck := smoothstep(bridge_span.x-100,bridge_span.x-30,d)*(1-smoothstep(bridge_span.y+30,bridge_span.y+100,d))
		width *= 1-deck
	if closed_loop and course_id == 0 and bridge_span.y > bridge_span.x:
		var viaduct := smoothstep(bridge_span.x-90,bridge_span.x,d)*(1-smoothstep(bridge_span.y,bridge_span.y+90,d))
		width *= 1-viaduct
	return 1.5+width*(1.0 if closed_loop else (1.0-route_node*0.10))

func roadside_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = scenery.terrain_point(distance,lane)
	if course_id >= 1 or in_tunnel(distance) or excavation_depth(distance) > 0.05: return p
	var side := signf(lane)
	var flat_edge := half_width(distance)+rail_setback(distance,side)+1.3
	var span := shoulder_bank_span(distance,side)
	if absf(lane) <= flat_edge+span:
		var far: Vector3 = scenery.terrain_point(distance,side*(flat_edge+span))
		p.y = maxf(p.y,lerpf(point(distance).y-0.025,far.y,clampf((absf(lane)-flat_edge)/span,0,1)))
	return p

func shoulder_bank_span(distance: float, side: float) -> float:
	if closed_loop and course_id == 0 and side < 0:
		# Broad natural lakeside slopes; tight hairpins cannot fold a bank across
		# the centre of their own curve. Steep constrained parts use rock shading.
		return clampf(0.35/maxf(absf(curvature(distance)),0.0001),12,80)
	return 8.0

func surface_lane(reference: float, distance: float) -> float:
	return reference*half_width(distance)/9 if absf(reference) <= 9 else signf(reference)*(half_width(distance)+absf(reference)-9)

func underpass_span() -> Vector2:
	return Vector2(length*0.46,length*0.46+240) if closed_loop and course_id == 0 else Vector2.ZERO

func on_bridge(distance: float) -> bool:
	if bridge_span.y <= bridge_span.x or (closed_loop and course_id not in [0,4]): return false
	var d := fposmod(distance,length) if closed_loop else distance
	return d >= bridge_span.x and d <= bridge_span.y

func in_tunnel(distance: float) -> bool:
	if course_id >= 1: return false
	if closed_loop:
		var d := fposmod(distance,length)
		var span := underpass_span()
		return d >= span.x and d <= span.y
	var span := Library.tunnel_span(stage,route_node)
	return span.y > span.x and distance >= span.x and distance <= span.y

func heading(distance: float) -> float:
	var f := point(distance+2)-point(distance-2)
	return atan2(-f.x,-f.z)

func curvature(distance: float) -> float:
	return wrapf(heading(distance+12)-heading(distance-12),-PI,PI) / 24

func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.65 if metallic == 0 else 0.28
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

func strip(left: float, right: float, height: float, mat: Material, begin: float = 0.0) -> MeshInstance3D:
	if collapse != null: return collapse.make_strip(left,right,height,mat,begin)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := int(ceil((length-begin)/2)) if closed_loop else 900
	var n := MeshInstance3D.new()
	n.material_override = mat
	add_child(n)
	var steps: Array[Callable] = []
	for from in range(1,segments+1,300): steps.append(func(): strip_part(st,left,right,height,begin,segments,from,mini(segments+1,from+300)))
	steps.append(func():
		st.generate_normals()
		n.mesh = st.commit())
	queue_next(steps)
	return n

func strip_edges(left: float, right: float, height: float, d: float) -> Array[Vector3]:
	# point(d,lane)는 lane에 대해 선형이므로 양쪽 가장자리를 한 번의 표본으로 구한다.
	var origin := point(d)
	var lateral := point(d,1)-origin
	var lift := Vector3.UP*(height+surface_lift)
	return [origin+lateral*surface_lane(left,d)+lift,origin+lateral*surface_lane(right,d)+lift]

func strip_part(st: SurfaceTool, left: float, right: float, height: float, begin: float, segments: int, from: int, to: int) -> void:
	var a := begin+(length-begin)*(from-1)/segments
	var near := strip_edges(left,right,height,a)
	for i in range(from,to):
		var b := begin+(length-begin)*i/segments
		var far := strip_edges(left,right,height,b)
		var points := [near[0],near[1],far[0],far[1]]
		var uvs := [Vector2(left / 6, a / 6), Vector2(right / 6, a / 6), Vector2(left / 6, b / 6), Vector2(right / 6, b / 6)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.set_uv(uvs[index])
			st.add_vertex(points[index])
		a = b
		near = far

func paint(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	mat.set_shader_parameter("paint_color", color)
	return mat

# 투어의 다음 구간은 주행 중에 만들어진다. staged이면 단계를 쌓아만 두고 Track이
# 프레임마다 조금씩 실행해, 한 프레임에 구간 전체를 만드는 멈춤을 없앤다.
var staged := false
var draining := false
var build_queue: Array[Callable] = []

func build_pending() -> bool:
	return not build_queue.is_empty()

# budget_usec < 0이면 남은 단계를 모두 실행한다. 완료되면 true.
func build_some(budget_usec: int = -1) -> bool:
	var started := Time.get_ticks_usec()
	draining = true
	while not build_queue.is_empty():
		var step: Callable = build_queue.pop_front()
		step.call()
		if budget_usec >= 0 and Time.get_ticks_usec()-started >= budget_usec: break
	draining = false
	if build_queue.is_empty(): staged = false
	return build_queue.is_empty()

# 실행 중인 단계가 자신을 나눈 하위 단계를 바로 다음 순서에 끼워 넣는다. 긴 메시와 풍경이 사용한다.
# 완성된 구간에 나중에 추가하는 형상은 곧바로 실행한다.
func queue_next(steps: Array[Callable]) -> void:
	for i in range(steps.size()-1,-1,-1): build_queue.push_front(steps[i])
	if not staged and not draining: build_some()

func _ready() -> void:
	if region_metadata.is_empty(): region_metadata = preload("res://scripts/tour_region_metadata.gd").resolve(Library.theme(stage,route_node))
	var Roadside := preload("res://scripts/roadside_geometry.gd")
	var ribbons := {}
	build_queue.append(func():
		if not closed_loop:
			for path in Scenery.warm_paths(Library.theme(stage,route_node)): preload("res://scripts/render_resources.gd").warm(path)
		if not closed_loop and stage == 0: bridge_span = Vector2(850,1380)
		if closed_loop and course_id == 4:
			collapse = preload("res://scripts/bridge_collapse.gd").new()
			collapse.configure(self)
			add_child(collapse)
		features = Features.layout(self)
		rng.seed = 8417
		strip(-10.5, 10.5, -0.15, material(Color("7e8477"))).name = "RoadBase")
	build_queue.append(func():
		var asphalt := ShaderMaterial.new()
		asphalt.shader = ASPHALT_SHADER
		asphalt.set_shader_parameter("rain_wetness",1.0 if region_metadata.get("weather","") == "rain" and not closed_loop else 0.0)
		asphalt.set_shader_parameter("asphalt_texture", ASPHALT)
		asphalt.set_shader_parameter("asphalt_variants",preload("res://assets/environment/asphalt-variants.png"))
		road_surface = strip(-9, 9, 0, asphalt)
		road_surface.name = "TexturedAsphalt")
	build_queue.append(func(): Features.build(self))
	build_queue.append(func(): strip(-8.6,-8.4,0.025,paint(Color("e7e6d6")),150 if entry_side > 0 else 0))
	build_queue.append(func(): strip(8.4,8.6,0.025,paint(Color("e7e6d6")),150 if entry_side < 0 else 0))
	build_queue.append(func(): Roadside.frames(self,ribbons))
	build_queue.append(func(): Roadside.rail(self,ribbons))
	build_queue.append(func(): Roadside.curbs(self,ribbons))
	build_queue.append(func(): Roadside.lane_marks(self,ribbons))
	build_queue.append(func(): Roadside.road_mass(self))
	build_queue.append(func():
		var post_transforms: Array[Transform3D] = []
		for i in range(0,int(length / 5),2):
			var d := i * 5.0
			for side in [-1, 1]:
				if d < 150 and side == -entry_side: continue
				post_transforms.append(Transform3D(Basis.IDENTITY, point(d, side * (half_width(d)+rail_setback(d,side))) + Vector3.UP * 0.6))
		box_batch(Vector3(0.24, 1.2, 0.28), material(Color("8d9c9c"), 0.6), post_transforms)
		make_curve_markers())
	build_queue.append(make_skid_marks)
	build_queue.append(func():
		if course_id == 1: scenery = preload("res://scripts/speedway_environment.gd").new()
		elif closed_loop and course_id == 2: scenery = preload("res://scripts/night_environment.gd").new()
		elif closed_loop and course_id == 3: scenery = preload("res://scripts/riviera_environment.gd").new()
		elif closed_loop and course_id == 4: scenery = preload("res://scripts/gorge_environment.gd").new()
		else: scenery = preload("res://scripts/circuit_environment.gd").new() if closed_loop else Scenery.new()
		scenery.track = self
		add_child(scenery))
	build_queue.append(func(): Roadside.shoulders(self))
	build_queue.append(func():
		if course_id == 0 or not closed_loop: make_course_banners()
		var stripe_d := 80.0 if stage == 0 else length - 10
		if stage == 0 or stage == 4:
			make_finish_stripe(stripe_d))
	build_queue.append(func():
		if closed_loop:
			if course_id == 1:
				speedway_board = preload("res://scripts/speedway_scoreboard.gd").new()
				speedway_board.road = self
				add_child(speedway_board)
			else: make_gantry(80,["FUJI LAKESIDE","SUNCOAST SPEEDWAY","MIDNIGHT HARBOR","AZURE RIVIERA","SCARLET GORGE"][clampi(course_id,0,4)]+" / START - FINISH")
		elif stage < 4:
			make_gantry(checkpoint_distance(),"CHECKPOINT",Color("e3ad38"))
			make_checkpoint_stripe(checkpoint_distance())
			var titles := Library.next_titles(stage,route_node)
			make_gantry(length-55,"< "+titles[0]+"     "+titles[1]+" >")
			make_fork_guides()
		else: make_gantry(length-10,"GRAND TOUR / GOAL")
		if collapse != null: collapse.finish_geometry()
		if closed_loop and course_id == 4:
			rockfall = preload("res://scripts/rockfall_hazard.gd").new()
			rockfall.configure(self)
			add_child(rockfall)
			rockfall.reset_effect())
	if not staged: build_some()

func checkpoint_distance() -> float:
	return maxf(80,length-Library.CHECKPOINT_RUNUP)

func make_finish_stripe(at: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := int(ceil(half_width(at)*2))
	for row in range(2):
		var a := at-0.6+row*1.2
		var b := a+1.2
		for i in range(columns):
			var left := -1.0+2.0*i/columns
			var right := -1.0+2.0*(i+1)/columns
			var points := [point(a,left*half_width(a)),point(a,right*half_width(a)),point(b,left*half_width(b)),point(b,right*half_width(b))]
			var uv := [Vector2(i,row),Vector2(i+1,row),Vector2(i,row+1),Vector2(i+1,row+1)]
			for index in [0,2,1,1,2,3]:
				st.set_uv(uv[index])
				st.add_vertex(points[index]+Vector3.UP*0.035)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "FinishStripe"
	node.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/finish_stripe.gdshader")
	mat.set_shader_parameter("asphalt_texture",ASPHALT)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

# A gantry sized to the road: slim posts just outside the rails, a dark lit panel with big, high
# contrast lettering, a chequered or hazard edge strip and a beacon on each post. Start/finish is
# navy with white lettering and a chequered strip; the checkpoint is amber with dark lettering.
func make_gantry(at: float, title: String, tint: Color = Color("173d46")) -> void:
	var checkpoint := title == "CHECKPOINT"
	var gantry := Node3D.new()
	add_child(gantry)
	gantry.position = point(at)
	gantry.rotation.y = heading(at)
	var reach := half_width(at)+maxf(rail_setback(at,1.0),rail_setback(at,-1.0))+2.2
	var steel := material(Color("56626b"),0.5)
	var panel_color := Color("f2b632") if checkpoint else (Color("0d1b2a") if title.ends_with("START - FINISH") or title.ends_with("GOAL") else tint)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = panel_color
	glow.emission_enabled = true
	glow.emission = panel_color
	glow.emission_energy_multiplier = 0.35
	var beacon_color := Color("ffcf4a") if checkpoint else Color("5fe3ff")
	var beacon := StandardMaterial3D.new()
	beacon.albedo_color = beacon_color
	beacon.emission_enabled = true
	beacon.emission = beacon_color
	beacon.emission_energy_multiplier = 2.2
	for side in [-1,1]:
		box(gantry,Vector3(side*reach,4.3,0),Vector3(0.45,8.6,0.45),steel)
		box(gantry,Vector3(side*reach,0.25,0),Vector3(1.2,0.5,1.2),material(Color("2b3239")))
		box(gantry,Vector3(side*reach,8.85,0),Vector3(0.7,0.5,0.7),beacon)
	var width := reach*2.0
	box(gantry,Vector3(0,8.1,0),Vector3(width,0.35,0.5),steel)
	var panel_width := minf(width-1.2,maxf(20.0,title.length()*0.72))
	box(gantry,Vector3(0,7.2,0),Vector3(panel_width,2.0,0.4),glow)
	box(gantry,Vector3(0,7.2,-0.01),Vector3(panel_width+0.25,2.25,0.3),material(Color("e8ecee")))
	# Edge strip under the panel: chequered for start/finish, hazard orange/dark for checkpoints.
	var cells := 24
	for i in range(cells):
		var light := i%2 == 0
		var strip: Color
		if checkpoint: strip = Color("1b1f24") if light else Color("f2b632")
		else: strip = Color("f7f7f2") if light else Color("14181c")
		box(gantry,Vector3(-panel_width*0.5+panel_width*(i+0.5)/cells,5.95,0.05),Vector3(panel_width/cells,0.4,0.25),material(strip))
	var label := Label3D.new()
	label.text = title
	label.font_size = 110
	label.pixel_size = minf(0.0095,(panel_width-1.6)/(maxf(title.length(),8)*62.0))
	label.outline_size = 0
	label.position = Vector3(0,7.2,0.24)
	label.modulate = Color("14181c") if checkpoint else Color("f7fbff")
	gantry.add_child(label)

# A bright band across the road under the checkpoint gantry.
func make_checkpoint_stripe(at: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(2):
		var a := at-1.3+row*1.4
		var b := a+1.2
		var points := [point(a,-half_width(a)),point(a,half_width(a)),point(b,-half_width(b)),point(b,half_width(b))]
		for index in [0,2,1,1,2,3]: st.add_vertex(points[index]+Vector3.UP*0.04)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "CheckpointStripe"
	node.mesh = st.commit()
	node.material_override = paint(Color("f2b632"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func make_fork_guides() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for remaining in [180.0,95.0,30.0]:
		var d: float = length-remaining
		var forward := (point(d+2)-point(d-2)).normalized()
		var right := Vector3(-forward.z,0,forward.x).normalized()
		for side in [-1.0,1.0]:
			var origin := point(d,side*half_width(d)*0.52)+Vector3.UP*0.05
			var direction: Vector3 = (forward+right*side*0.38).normalized()
			var across := Vector3(-direction.z,0,direction.x).normalized()
			var points := [Vector2(-0.4,-3),Vector2(0.4,-3),Vector2(-0.4,1),Vector2(0.4,1),Vector2(-1.6,1),Vector2(1.6,1),Vector2(0,4)]
			for index in [0,2,1,1,2,3,4,6,5]:
				mesh.add_vertex(origin+across*points[index].x+direction*points[index].y)
	mesh.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "ForkRoadArrows"
	node.mesh = mesh.commit()
	node.material_override = paint(Color("f1eee4"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func make_skid_marks() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SKID_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	for run in range(12):
		var start := length * (0.012 + run * 0.078)
		var run_length := 65.0 + 20.0 * sin(run * 2.1)
		var direction := -1.0 if run % 2 == 0 else 1.0
		for wheel in [-1, 1]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for segment in range(36):
				var t0 := segment / 36.0
				var t1 := (segment + 1) / 36.0
				var a := start + t0 * run_length
				var b := start + t1 * run_length
				var lane_a: float = direction * (1.1 + sin(t0 * PI) * 2.7) + wheel * 0.79
				var lane_b: float = direction * (1.1 + sin(t1 * PI) * 2.7) + wheel * 0.79
				var vertices := [point(a, lane_a - 0.14), point(a, lane_a + 0.14), point(b, lane_b - 0.14), point(b, lane_b + 0.14)]
				var uvs := [Vector2(0, t0), Vector2(1, t0), Vector2(0, t1), Vector2(1, t1)]
				for index in [0, 2, 1, 1, 2, 3]:
					st.set_uv(uvs[index])
					st.set_normal(Vector3.UP)
					st.add_vertex(vertices[index] + Vector3.UP * 0.038)
			var node := MeshInstance3D.new()
			node.mesh = st.commit()
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			skid_meshes.append(node)

func box_batch(size: Vector3, mat: Material, transforms: Array[Transform3D]) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.material_override = mat
	add_child(node)
	prop_batches.append(node)

func make_curve_markers() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/environment/curve-chevron.svg")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3,1.5)
	var poses: Array[Transform3D] = []
	var cases: Array[Transform3D] = []
	var supports: Array[Transform3D] = []
	for i in range(int(length/65)):
		var d := 35.0+i*65
		var bend := wrapf(heading(d+40)-heading(d),-PI,PI)
		if closed_loop and course_id in [1,4] and absf(bend) < 0.10: continue
		var side := 1.0 if bend > 0 else -1.0
		if d < 150 and side == -entry_side: continue
		var wall_mounted := in_tunnel(d) or excavation_depth(d) > 0.05
		var offset := rail_setback(d,side)+1.8
		var angle := heading(d)
		if wall_mounted:
			# Exterior boards cross the shell when placed across the road. Mount
			# these parallel to the inside face, with a real gap from the wall.
			offset = 0.75 if closed_loop else 1.80
			angle -= side*PI/2
		poses.append(Transform3D(Basis(Vector3.UP,angle).scaled_local(Vector3(side,1,1)),point(d,side*(half_width(d)+offset))+Vector3.UP*1.9))
		var pose: Transform3D = poses[-1]
		cases.append(pose*Transform3D(Basis.IDENTITY,Vector3(0,0,-.13)))
		if wall_mounted:
			for y in [-.38,.38]: supports.append(pose*Transform3D(Basis.IDENTITY.scaled_local(Vector3(2.6,.12,.10)),Vector3(0,y,-.30)))
		else:
			supports.append(pose*Transform3D(Basis.IDENTITY.scaled_local(Vector3(.20,1.60,.24)),Vector3(0,-1.10,-.16)))
		curve_marker_distances.append(d)
		curve_marker_tunnel.append(wall_mounted)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
	curve_marker_transforms.assign(poses)
	curve_markers = MultiMeshInstance3D.new()
	curve_markers.name = "CurveDirectionSigns"
	curve_markers.multimesh = multi
	curve_markers.material_override = mat
	curve_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(curve_markers)

	box_batch(Vector3(3.16,1.66,.24),material(Color("343f49"),.5),cases)
	prop_batches[-1].name = "CurveSignCases"
	prop_batches[-1].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box_batch(Vector3.ONE,material(Color("809097"),.65),supports)
	prop_batches[-1].name = "CurveSignSupports"
	prop_batches[-1].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_course_banners() -> void:
	var poles: Array[Transform3D] = []
	var poses: Array[Transform3D] = []
	for i in range(int(length/95)):
		var d := 55.0+i*95
		if in_tunnel(d) or excavation_depth(d) > 0.05: continue
		if bridge_span.y > bridge_span.x and d > bridge_span.x-50 and d < bridge_span.y+50: continue
		for side in [-1.0,1.0]:
			if d < 150 and side == -entry_side: continue
			var base: Vector3 = roadside_point(d,side*(half_width(d)+rail_setback(d,side)+3.3))
			poles.append(Transform3D(Basis.IDENTITY,base+Vector3.UP*3.8))
			var center := point(d,side*(half_width(d)+rail_setback(d,side)+2.5))
			center.y = base.y+4.3
			poses.append(Transform3D(Basis(Vector3.UP,heading(d)).scaled_local(Vector3(-side,1,1)),center))
	box_batch(Vector3(0.16,7.6,0.16),material(Color("899aa1"),0.6),poles)
	var flags := MultiMesh.new()
	flags.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.6,6.4)
	mesh.subdivide_depth = 10
	flags.mesh = mesh
	flags.instance_count = poses.size()
	for i in range(poses.size()): flags.set_instance_transform(i,poses[i])
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/course_banner.gdshader")
	var node := MultiMeshInstance3D.new()
	node.multimesh = flags
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
