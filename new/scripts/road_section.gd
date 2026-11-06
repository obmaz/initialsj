extends Node3D

const WIDTH := 18.0
const Features = preload("res://scripts/road_features.gd")
const Scenery = preload("res://scripts/road_biome.gd")
const Library = preload("res://scripts/route_library.gd")
const ASPHALT = preload("res://assets/environment/asphalt.png")
const ASPHALT_SHADER = preload("res://shaders/asphalt.gdshader")
const PAINT_SHADER = preload("res://shaders/road_paint.gdshader")
const SKID_SHADER = preload("res://shaders/skid_marks.gdshader")
var features: Array[Dictionary] = []
var closed_loop := false
var course_id := 0
var map_widths: Array[Vector2] = []
var scenery: Node3D
var road_surface: MeshInstance3D
var skid_meshes: Array[MeshInstance3D] = []
var prop_batches: Array[MultiMeshInstance3D] = []
var curve := Curve3D.new()
var length := 0.0
var rng := RandomNumberGenerator.new()

var stage := 0
var route_node := 0
var entry_side := 0
var start_heading := -PI / 2
var start_point := Vector3(0,6,0)
var surface_lift := 0.0

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
		var envelope := smoothstep(200,360,d)*(1-smoothstep(span-280,span-100,d))
		var severity := 1.0+route_node*0.18
		var wave := (0.42+stage*0.025)*severity*sin(TAU*(2.0+route_node*0.18)*t)
		wave += (0.14+route_node*0.025)*sin(TAU*(4.0+route_node*0.28)*t)*pow(sin(PI*t),2)
		var angle := start_heading-side*0.38*smoothstep(0,180,d)+wave*envelope
		if i > 0: p += Vector3(-sin(angle),0,-cos(angle))*5
		p.y = origin.y+(28+stage*6+route_node*3)*pow(sin(PI*t),2)*smoothstep(160,300,d)
		curve.add_point(p)
	length = curve.get_baked_length()

func point(distance: float, lane: float = 0) -> Vector3:
	var d := fposmod(distance,length) if closed_loop else clampf(distance,0,length)
	var p := curve.sample_baked(d,false)
	var a := curve.sample_baked(fposmod(d-2,length) if closed_loop else clampf(d-2,0,length),false)
	var b := curve.sample_baked(fposmod(d+2,length) if closed_loop else clampf(d+2,0,length),false)
	var forward := (b-a).normalized()
	if distance != d and not closed_loop: p += forward * (distance-d)
	return p + Vector3(-forward.z,0,forward.x).normalized() * lane

func half_width(distance: float) -> float:
	if course_id == 1 and not map_widths.is_empty():
		var d := fposmod(distance,length)
		for i in range(map_widths.size()-1):
			if d <= map_widths[i+1].x:
				var a := map_widths[i]
				var b := map_widths[i+1]
				return lerpf(a.y,b.y,smoothstep(a.x,b.x,d))
		return map_widths[-1].y
	if closed_loop:
		var t := fposmod(distance,length)/length
		var straight := 1-smoothstep(0.14,0.21,t)
		var hairpin := smoothstep(0.27,0.32,t)*(1-smoothstep(0.39,0.44,t))
		return 8.7+straight*1.1-hairpin*1.1+0.3*sin(TAU*t)
	var t := clampf(distance/length,0,1)
	var blend := smoothstep(180,360,distance)*(1-smoothstep(length-360,length-180,distance))
	var width := 9.8-route_node*0.50+1.5*sin(TAU*(1.5+route_node*0.12)*t+stage*0.7)
	width -= 1.1*smoothstep(0.36,0.43,t)*(1-smoothstep(0.62,0.69,t))
	return lerpf(9.0,clampf(width,6.2,11.5),blend)

func surface_lane(reference: float, distance: float) -> float:
	return reference*half_width(distance)/9 if absf(reference) <= 9 else signf(reference)*(half_width(distance)+absf(reference)-9)

func in_tunnel(distance: float) -> bool:
	if course_id == 1: return false
	if closed_loop:
		var d := fposmod(distance,length)
		return d >= length*0.56 and d <= length*0.56+240
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(900):
		var a := begin + (length-begin) * i / 900.0
		var b := begin + (length-begin) * (i+1) / 900.0
		var points := [point(a,surface_lane(left,a)),point(a,surface_lane(right,a)),point(b,surface_lane(left,b)),point(b,surface_lane(right,b))]
		var uvs := [Vector2(left / 6, a / 6), Vector2(right / 6, a / 6), Vector2(left / 6, b / 6), Vector2(right / 6, b / 6)]
		for index in [0, 2, 1, 1, 2, 3]:
			st.set_uv(uvs[index])
			st.add_vertex(points[index] + Vector3.UP * (height + surface_lift))
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	add_child(n)
	return n

func paint(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAINT_SHADER
	mat.set_shader_parameter("asphalt_texture", ASPHALT)
	mat.set_shader_parameter("paint_color", color)
	return mat

func _ready() -> void:
	features = Features.layout(self)
	rng.seed = 8417
	var asphalt := ShaderMaterial.new()
	asphalt.shader = ASPHALT_SHADER
	asphalt.set_shader_parameter("asphalt_texture", ASPHALT)
	strip(-10.5, 10.5, -0.15, material(Color("7e8477")))
	road_surface = strip(-9, 9, 0, asphalt)
	road_surface.name = "TexturedAsphalt"
	Features.build(self)
	strip(-8.6,-8.4,0.025,paint(Color("e7e6d6")),150 if entry_side > 0 else 0)
	strip(8.4,8.6,0.025,paint(Color("e7e6d6")),150 if entry_side < 0 else 0)
	var lane_marks: Array[Transform3D] = []
	for i in range(int(length / 12)):
		var d := i * 12.0 + 3
		var f := (point(d+2)-point(d)).normalized()
		var basis := Basis(Vector3.UP,heading(d)).rotated(Vector3(-f.z,0,f.x).normalized(),asin(f.y))
		for center in [-0.5,0.0,0.5]: lane_marks.append(Transform3D(basis,point(d,center*half_width(d))+Vector3.UP*0.027))
	box_batch(Vector3(0.11,0.015,5),paint(Color("e0e3df")),lane_marks)
	var red := paint(Color("c94c48"))
	var white := paint(Color("e9e7db"))
	var steel := material(Color("8d9c9c"), 0.6)
	var rail_transforms: Array[Transform3D] = []
	var post_transforms: Array[Transform3D] = []
	var red_transforms: Array[Transform3D] = []
	var white_transforms: Array[Transform3D] = []
	for i in range(int(length / 5)):
		var d := i * 5.0
		for side in [-1, 1]:
			if d < 150 and side == -entry_side: continue
			rail_transforms.append(Transform3D(Basis(Vector3.UP, heading(d)), point(d, side * (half_width(d)+1.5)) + Vector3.UP * 0.9))
			if i % 3 == 0:
				post_transforms.append(Transform3D(Basis.IDENTITY, point(d, side * (half_width(d)+1.5)) + Vector3.UP * 0.4))
	for i in range(int(length / 3)):
		var d := i * 3.0
		for side in [-1, 1]:
			if d < 150 and side == -entry_side: continue
			var transform := Transform3D(Basis(Vector3.UP, heading(d)), point(d, side * (half_width(d)+0.1)))
			if i % 2 == 0:
				red_transforms.append(transform)
			else:
				white_transforms.append(transform)
	box_batch(Vector3(0.18, 0.45, 5.15), steel, rail_transforms)
	box_batch(Vector3(0.16, 1.0, 0.16), steel, post_transforms)
	box_batch(Vector3(0.7, 0.13, 3.05), red, red_transforms)
	box_batch(Vector3(0.7, 0.13, 3.05), white, white_transforms)
	make_curve_markers()
	make_skid_marks()
	if course_id == 1: scenery = preload("res://scripts/seocho_environment.gd").new()
	else: scenery = preload("res://scripts/circuit_environment.gd").new() if closed_loop else Scenery.new()
	scenery.track = self
	add_child(scenery)
	make_course_banners()
	var stripe_d := 80.0 if stage == 0 else length - 10
	if stage == 0 or stage == 4:
		for i in range(18):
			for row in range(2):
				var tile := box(self,point(stripe_d + row * 1.2,i-8.5) + Vector3.UP * 0.035,Vector3(1,0.025,1.2),white if (i+row)%2 == 0 else asphalt)
				tile.rotation.y = heading(stripe_d)
	var gantry := Node3D.new()
	add_child(gantry)
	gantry.position = point(80 if closed_loop else (length + Library.FORK_COMMIT if stage < 4 else length - 10))
	gantry.rotation.y = heading(80 if closed_loop else length)
	for side in [-1,1]: box(gantry,Vector3(side * 16,4.5,0),Vector3(0.5,9,0.5),steel)
	box(gantry,Vector3(0,8.5,0),Vector3(33,2.3,0.6),material(Color("173d46")))
	var sign_label := Label3D.new()
	var titles := Library.next_titles(stage,route_node)
	sign_label.text = ("SEOCHO LOOP / START - FINISH" if course_id == 1 else "FUJI LAKESIDE / START - FINISH") if closed_loop else ("< " + titles[0] + "   |   " + titles[1] + " >" if stage < 4 else "GRAND TOUR / GOAL")
	sign_label.font_size = 90
	sign_label.pixel_size = 0.008
	sign_label.position = Vector3(0,8.5,0.35)
	gantry.add_child(sign_label)

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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3,1.5)
	var poses: Array[Transform3D] = []
	for i in range(int(length/65)):
		var d := 35.0+i*65
		var bend := wrapf(heading(d+40)-heading(d),-PI,PI)
		var side := 1.0 if bend > 0 else -1.0
		if d < 150 and side == -entry_side: continue
		poses.append(Transform3D(Basis(Vector3.UP,heading(d)).scaled_local(Vector3(side,1,1)),point(d,side*(half_width(d)+3.3))+Vector3.UP*1.9))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func make_course_banners() -> void:
	var poles: Array[Transform3D] = []
	var poses: Array[Transform3D] = []
	for i in range(int(length/95)):
		var d := 55.0+i*95
		for side in [-1.0,1.0]:
			if d < 150 and side == -entry_side: continue
			var base: Vector3 = scenery.terrain_point(d,side*(half_width(d)+4.8))
			poles.append(Transform3D(Basis.IDENTITY,base+Vector3.UP*3.8))
			var center := point(d,side*(half_width(d)+4))
			center.y = base.y+4.3
			poses.append(Transform3D(Basis(Vector3.UP,heading(d)).scaled_local(Vector3(-side,1,1)),center))
	box_batch(Vector3(0.08,7.6,0.08),material(Color("899aa1"),0.6),poles)
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
