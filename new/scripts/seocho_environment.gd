extends Node3D
# Temporary location photographs sit behind a lit 3D streetscape. No photo is
# represented as a live Street View capture; exact provenance lives in data/.
const Course = preload("res://scripts/seocho_course.gd")
const PINE = preload("res://assets/environment/japanese-pine.png")
const PHOTOS = [preload("res://assets/environment/seocho/maple-gate.jpg"),preload("res://assets/environment/seocho/academy-building.jpg"),preload("res://assets/environment/seocho/mido-apartments.png"),preload("res://assets/environment/seocho/gyodae-station.jpg")]
const PLACES := [
	{"name":"MAPLE / COMPLEX 2","lat":37.5113975,"lon":127.0134451,"photo":0,"side":1.0,"height":19.0,"credit":"Photo: Maeil Business / 2025.07"},
	{"name":"KIPARANG / CHEONGGU BLDG","lat":37.5019187,"lon":127.010677,"photo":1,"side":1.0,"height":8.0,"credit":"Photo: Marusim / ground floor, same building"},
	{"name":"BANPO MIDO / SIDE ROAD","lat":37.5003466,"lon":127.0100157,"photo":2,"side":-1.0,"height":17.0,"credit":"Photo: DNews / 2017.09"},
	{"name":"GYODAE STATION","lat":37.493683,"lon":127.0136817,"photo":3,"side":-1.0,"height":15.0,"credit":"Photo: Seoul Institute / 2015.02"}
]
var track: Node3D
var theme := "seocho"
var locations: Array[Dictionary] = []
var photo_sky: ShaderMaterial
var active_photo := -1
var photo_blend := 1.0
func make_sky() -> Sky:
	var sky := Sky.new()
	photo_sky = ShaderMaterial.new()
	photo_sky.shader = preload("res://shaders/seocho_photo_sky.gdshader")
	sky.sky_material = photo_sky
	update_photo(80)
	return sky
func terrain_point(d: float, lane: float) -> Vector3:
	return track.point(d,lane)-Vector3.UP*0.12
func update_photo(distance: float, delta: float = 0) -> void:
	if photo_sky == null: return
	var best := INF
	var index := 0
	for i in range(locations.size()):
		var gap := absf(wrapf(distance-locations[i].distance,-track.length/2,track.length/2))
		if gap < best: best = gap; index = i
	if active_photo != index:
		var old := index if active_photo < 0 else active_photo
		photo_sky.set_shader_parameter("photo_previous",PHOTOS[2 if old == 1 else old])
		var old_f: Vector3 = track.point(locations[old].distance+2)-track.point(locations[old].distance-2)
		photo_sky.set_shader_parameter("previous_yaw",atan2(old_f.x,old_f.z))
		photo_blend = 1.0 if active_photo < 0 else 0.0
		active_photo = index
		# Ground-floor facade stays on its building, rather than becoming a skyline.
		photo_sky.set_shader_parameter("photo",PHOTOS[2 if index == 1 else index])
		var f: Vector3 = track.point(locations[index].distance+2)-track.point(locations[index].distance-2)
		photo_sky.set_shader_parameter("center_yaw",atan2(f.x,f.z))
	photo_blend = minf(1,photo_blend+delta*0.85)
	photo_sky.set_shader_parameter("photo_blend",photo_blend)
func _ready() -> void:
	for place in PLACES:
		var d: float = track.curve.get_closest_offset(Course.project(place))
		locations.append({"distance":d,"name":place.name,"credit":place.credit})
	make_city()
	make_crossings()
	make_academy_facade()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7000,7000)
	ground.mesh = plane
	ground.material_override = track.material(Color("777e78"))
	ground.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.position = Vector3(0,5.72,1000)
	add_child(ground)

func make_academy_facade() -> void:
	var d: float = locations[1].distance
	var height := 23.0
	var center: Vector3 = track.point(d,track.half_width(d)+10)
	var building: MeshInstance3D = track.box(self,center+Vector3.UP*height*0.5,Vector3(9,height,14),track.material(Color("aea897")))
	building.rotation.y = track.heading(d)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(6.2,4.0)
	panel.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PHOTOS[1]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.material_override = mat
	panel.position = track.point(d,track.half_width(d)+5.48)+Vector3.UP*2
	panel.rotation.y = track.heading(d)-PI*0.5
	add_child(panel)
func make_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2531010
	var blocks: Array[Transform3D] = []
	var glass: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	for i in range(int(track.length/42)):
		var d := i*42.0
		for side in [-1.0,1.0]:
			var width := rng.randf_range(12,22)
			var depth := rng.randf_range(11,19)
			var height := rng.randf_range(13,40)
			if d < 450 or d > track.length-420: height = rng.randf_range(58,100)
			var lane: float = side*(track.half_width(d)+10+depth*0.5)
			var p: Vector3 = track.point(d,lane)
			# Keep every building out of every leg of the mapped route.
			var near_d: float = track.curve.get_closest_offset(p)
			if track.point(near_d).distance_to(p) < track.half_width(near_d)+maxf(depth,width)*0.65+3: continue
			var skip := false
			for location in locations:
				if absf(wrapf(d-location.distance,-track.length/2,track.length/2)) < 48: skip = true
			if skip: continue
			var basis := Basis(Vector3.UP,track.heading(d))
			blocks.append(Transform3D(basis.scaled_local(Vector3(depth,height,width)),p+Vector3.UP*height*0.5))
			roofs.append(Transform3D(basis.scaled_local(Vector3(depth+0.5,0.5,width+0.5)),p+Vector3.UP*height))
			for floor_index in range(int(height/3.4)):
				var window_y := 2.2+floor_index*3.4
				var face: Vector3 = track.point(d,lane-side*(depth*0.5+0.04))+Vector3.UP*window_y
				glass.append(Transform3D(basis.scaled_local(Vector3(0.12,1.55,width*0.82)),face))
			if i%2 == 0:
				var tp: Vector3 = track.point(d,side*(track.half_width(d)+3.0))
				var tree_height := 6.8
				var tree_width: float = tree_height*PINE.get_width()/PINE.get_height()
				trees.append(Transform3D(Basis.IDENTITY.scaled(Vector3(tree_width,tree_height,1)),tp+Vector3.UP*tree_height*0.5))
	batch(blocks,Color("bbc0bd"),0,true)
	batch(glass,Color("476575"),0.35)
	batch(roofs,Color("727f7b"))
	var foliage := MultiMesh.new()
	foliage.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	foliage.mesh = quad
	foliage.instance_count = trees.size()
	for i in range(trees.size()): foliage.set_instance_transform(i,trees[i])
	var tree_node := MultiMeshInstance3D.new()
	tree_node.multimesh = foliage
	var leaves := StandardMaterial3D.new()
	leaves.albedo_texture = PINE
	leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaves.alpha_scissor_threshold = 0.3
	leaves.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	leaves.billboard_keep_scale = true
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tree_node.material_override = leaves
	add_child(tree_node)
	# Continuous sidewalks follow the measured road width.
	for side in [-1,1]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1400):
			var a: float = track.length*i/1400
			var b: float = track.length*(i+1)/1400
			var pts := [track.point(a,side*(track.half_width(a)+1)),track.point(a,side*(track.half_width(a)+5)),track.point(b,side*(track.half_width(b)+1)),track.point(b,side*(track.half_width(b)+5))]
			for n in [0,2,1,1,2,3]: st.add_vertex(pts[n]+Vector3.UP*0.08)
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.material_override = track.material(Color("9fa8a7"))
		add_child(node)
func batch(transforms: Array[Transform3D], color: Color, metallic: float = 0, varied: bool = false) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = varied
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	instances.mesh = cube
	instances.instance_count = transforms.size()
	var palette := [Color("d0c8b8"),Color("bbc0bd"),Color("85979e"),Color("ad9682"),Color("83999c")]
	for i in range(transforms.size()):
		instances.set_instance_transform(i,transforms[i])
		if varied: instances.set_instance_color(i,palette[i%palette.size()])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	var mat: StandardMaterial3D = track.material(Color.WHITE if varied else color,metallic)
	mat.vertex_color_use_as_albedo = varied
	node.material_override = mat
	if metallic > 0: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
func make_crossings() -> void:
	var paint: Array[Transform3D] = []
	for location in locations:
		var d: float = location.distance+35
		var width: float = track.half_width(d)
		for i in range(int(width*2/1.1)):
			paint.append(Transform3D(Basis(Vector3.UP,track.heading(d)),track.point(d,-width+0.6+i*1.1)+Vector3.UP*0.047))
	track.box_batch(Vector3(0.52,0.016,4.5),track.paint(Color("e7e4c9")),paint)
