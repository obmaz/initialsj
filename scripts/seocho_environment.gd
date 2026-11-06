extends Node3D
# Ten reference-inspired generated landmarks, with no repeated roadside buildings
# or photographic backdrop. All geographic anchors remain reviewable below.
const Course = preload("res://scripts/seocho_course.gd")
const MAJOR = preload("res://assets/environment/seocho/major-landmarks.png")
const LOCAL = preload("res://assets/environment/seocho/neighborhood-landmarks.png")
const PANORAMA = preload("res://assets/environment/seocho/skyline-panorama.png")
const MAJOR_REGIONS := [Vector4(.02994792,.01367188,.44791667,.50976562),Vector4(.50325521,.06054688,.49283854,.43847656),Vector4(.01236979,.5625,.48763021,.40332031),Vector4(.51627604,.64648438,.46744792,.30761719)]
const LOCAL_REGIONS := [Vector4(.00846354,.02441406,.31705729,.48925781),Vector4(.34114583,.1015625,.31510417,.40917969),Vector4(.67252604,.125,.31770833,.39648438),Vector4(.01302083,.53613281,.30143229,.43945312),Vector4(.34179688,.58300781,.3046875,.39355469),Vector4(.66861979,.61816406,.31966146,.36035156)]
const PLACES := [
	{"name":"MAPLE / COMPLEX 2","lat":37.5113975,"lon":127.0134451,"world_lat":37.51209,"world_lon":127.01348,"atlas":1,"region":0,"height":78.0,"side":-1.0},
	{"name":"BANPO STATION / SHOPS","lat":37.50825,"lon":127.0120,"atlas":1,"region":2,"height":20.0,"side":-1.0},
	{"name":"BANPO GREEN / FUEL","lat":37.5031457,"lon":127.0109010,"atlas":0,"region":3,"height":7.0,"side":-1.0},
	{"name":"KIPARANG / CHEONGGU BLDG","lat":37.5019187,"lon":127.010677,"world_lat":37.5018943,"world_lon":127.010484,"atlas":1,"region":3,"height":21.0,"side":1.0},
	{"name":"BANPO MIDO / SIDE ROAD","lat":37.5003466,"lon":127.0100157,"world_lat":37.5011518,"world_lon":127.0083821,"atlas":1,"region":1,"height":39.0,"side":1.0},
	{"name":"SEOUL COURT COMPLEX","lat":37.4961786,"lon":127.0112577,"atlas":0,"region":1,"height":58.0,"side":1.0},
	{"name":"GYODAE STATION","lat":37.493683,"lon":127.0136817,"atlas":1,"region":4,"height":4.4,"side":1.0},
	{"name":"SEOCHO STATION","lat":37.4918528,"lon":127.0077239,"atlas":1,"region":5,"height":4.2,"side":1.0},
	{"name":"SEOUL ST MARY'S HOSPITAL","lat":37.5017397,"lon":127.0047391,"atlas":0,"region":0,"height":79.0,"side":1.0},
	{"name":"EXPRESS BUS TERMINAL","lat":37.5056867,"lon":127.0062251,"atlas":0,"region":2,"height":37.0,"side":1.0}
]
const VISIT_NAMES := ["MAPLE / COMPLEX 2","KIPARANG / CHEONGGU BLDG","BANPO MIDO / SIDE ROAD","GYODAE STATION"]
var track: Node3D
var theme := "seocho"
var locations: Array[Dictionary] = []
var landmark_positions: Array[Vector3] = []
var active_landmark := -1
var update_clock := 0.0
func make_sky() -> Sky:
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/fuji_sky.gdshader")
	material.set_shader_parameter("panorama",PANORAMA)
	material.set_shader_parameter("center_yaw",0.0)
	material.set_shader_parameter("horizontal_span",TAU)
	material.set_shader_parameter("vertical_span",1.5)
	material.set_shader_parameter("horizon_uv",0.90)
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky
func terrain_point(d: float, lane: float) -> Vector3:
	return track.point(d,lane)-Vector3.UP*0.12
func update_landmark(distance: float, delta: float) -> void:
	update_clock -= delta
	if update_clock > 0: return
	update_clock = 0.15
	active_landmark = -1
	var best := 200.0
	for i in range(locations.size()):
		var gap := absf(wrapf(distance-locations[i].distance,-track.length/2,track.length/2))
		if gap < best: best = gap; active_landmark = i
func _ready() -> void:
	make_landmarks()
	make_terrain()
	make_sidewalks()
	make_crossings()
func make_landmarks() -> void:
	var poses := [[],[]]
	var regions := [[],[]]
	for place in PLACES:
		var anchor := Course.project(place)
		var d: float = track.curve.get_closest_offset(anchor)
		var source := {"lat":place.get("world_lat",place.lat),"lon":place.get("world_lon",place.lon)}
		var p := Course.project(source)
		var texture: Texture2D = MAJOR if place.atlas == 0 else LOCAL
		var region: Vector4 = MAJOR_REGIONS[place.region] if place.atlas == 0 else LOCAL_REGIONS[place.region]
		var height: float = place.height
		var width: float = height*region.z*texture.get_width()/(region.w*texture.get_height())
		var nearest: float = track.curve.get_closest_offset(p)
		var center: Vector3 = track.point(nearest)
		var outward := p-center
		outward.y = 0
		if outward.length() < 1:
			outward = track.point(nearest,place.side)-center
		var clearance: float = track.half_width(nearest)+4+width*0.5
		var shift := maxf(0,clearance-outward.length())
		p += outward.normalized()*shift
		p.y = Course.height_at(p)
		landmark_positions.append(p)
		locations.append({"name":place.name,"distance":d,"position":p,"clearance_shift_m":shift,"source_position":Course.project(source)})
		poses[place.atlas].append(Transform3D(Basis.IDENTITY.scaled(Vector3(width,height,1)),p+Vector3.UP*height*0.5))
		regions[place.atlas].append(Color(region.x,region.y,region.z,region.w))
		var foundation: MeshInstance3D = track.box(self,p-Vector3.UP*1.0,Vector3(width*0.72,2.0,5.0),track.material(Color("8c9182")))
		foundation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index in range(2):
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		multi.mesh = quad
		multi.instance_count = poses[index].size()
		for i in range(poses[index].size()):
			multi.set_instance_transform(i,poses[index][i])
			multi.set_instance_custom_data(i,regions[index][i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/roadside_sprite.gdshader")
		material.set_shader_parameter("atlas",MAJOR if index == 0 else LOCAL)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
func make_terrain() -> void:
	var bounds := AABB(track.point(0),Vector3.ZERO)
	for i in range(200): bounds = bounds.expand(track.point(track.length*i/200))
	var left: float = floor((bounds.position.x-300)/80)*80
	var back: float = floor((bounds.position.z-300)/80)*80
	var columns := int(ceil((bounds.size.x+600)/80))
	var rows := int(ceil((bounds.size.z+600)/80))
	var grid: Array[Vector3] = []
	for z in range(rows+1):
		for x in range(columns+1):
			var p := Vector3(left+x*80,0,back+z*80)
			p.y = Course.height_at(p)
			var d: float = track.curve.get_closest_offset(p)
			var road: Vector3 = track.point(d)
			var gap := Vector2(p.x-road.x,p.z-road.z).length()
			p.y = lerpf(road.y-1.5,p.y-1.5,smoothstep(25,120,gap))
			grid.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(rows):
		for x in range(columns):
			var a := z*(columns+1)+x
			for i in [a,a+columns+1,a+1,a+1,a+columns+1,a+columns+2]:
				st.set_uv(Vector2(grid[i].x,grid[i].z)/24)
				st.add_vertex(grid[i])
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "SRTMStreetTerrain"
	terrain.mesh = st.commit()
	var mat: StandardMaterial3D = track.material(Color("737d69"))
	mat.roughness = 1
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	terrain.material_override = mat
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
func make_sidewalks() -> void:
	for side in [-1,1]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1000):
			var a: float = track.length*i/1000
			var b: float = track.length*(i+1)/1000
			var pts := [track.point(a,side*(track.half_width(a)+1)),track.point(a,side*(track.half_width(a)+9)),track.point(b,side*(track.half_width(b)+1)),track.point(b,side*(track.half_width(b)+9))]
			for n in [0,2,1,1,2,3]: st.add_vertex(pts[n]+Vector3.UP*0.08)
		st.generate_normals()
		var node := MeshInstance3D.new()
		node.mesh = st.commit()
		node.material_override = track.material(Color("969d93"))
		add_child(node)
func make_crossings() -> void:
	var paint: Array[Transform3D] = []
	for location in locations:
		if not ("STATION" in location.name or "KIPARANG" in location.name): continue
		var d: float = location.distance+25
		var width: float = track.half_width(d)
		for i in range(int(width*2/1.1)):
			paint.append(Transform3D(Basis(Vector3.UP,track.heading(d)),track.point(d,-width+0.6+i*1.1)+Vector3.UP*0.047))
	track.box_batch(Vector3(0.52,0.016,4.5),track.paint(Color("e7e4c9")),paint)
