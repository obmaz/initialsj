extends RefCounted
# Continuous ribbons share their edge vertices; there are no overlapping rail boxes.
static func build(section: Node3D) -> void:
	var steel: StandardMaterial3D = section.material(Color("9aa9af"),0.65)
	steel.roughness = 0.38
	var rail := SurfaceTool.new()
	rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	rail.set_smooth_group(0)
	var profile := [Vector2(-0.055,0.22),Vector2(0.055,0.14),Vector2(-0.035,0.03),Vector2(0.055,-0.07),Vector2(-0.055,-0.22)]
	var samples: Array[float] = [0.0]
	while samples[-1] < section.length:
		var at := samples[-1]
		var bend := absf(wrapf(section.heading(at+2)-section.heading(at-2),-PI,PI))/4
		samples.append(minf(section.length,at+clampf(0.045/maxf(bend,0.0001),0.4,2.0)))
	var steps := samples.size()-1
	for side in [-1.0,1.0]:
		for i in range(steps):
			var a: float = samples[i]
			var b: float = samples[i+1]
			if a < 150 and side == -section.entry_side: continue
			var da: float = side*(section.half_width(a)+section.rail_setback(a,side))
			var db: float = side*(section.half_width(b)+section.rail_setback(b,side))
			for band in range(profile.size()-1):
				var points := [section.point(a,da+profile[band].x*side)+Vector3.UP*(0.9+profile[band].y),section.point(a,da+profile[band+1].x*side)+Vector3.UP*(0.9+profile[band+1].y),section.point(b,db+profile[band].x*side)+Vector3.UP*(0.9+profile[band].y),section.point(b,db+profile[band+1].x*side)+Vector3.UP*(0.9+profile[band+1].y)]
				for index in ([0,2,1,1,2,3] if side > 0 else [0,1,2,1,3,2]): rail.add_vertex(points[index])
	rail.index()
	rail.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "ContinuousGuardrails"
	node.mesh = rail.commit()
	node.material_override = steel
	section.add_child(node)
	markings(section,samples)

static func shoulders(section: Node3D) -> void:
	if section.closed_loop and section.course_id == 1: return # Speedway has a paved apron and safety walls.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(ceil(section.length/5))
	for side in [-1.0,1.0]:
		for i in range(steps):
			var a: float = section.length*i/steps
			var b: float = section.length*(i+1)/steps
			if a < 150 and side == -section.entry_side: continue
			if section.in_tunnel((a+b)*0.5) or section.excavation_depth((a+b)*0.5) > 0.05: continue
			var left: float = section.half_width(a)+0.42
			var right: float = section.half_width(b)+0.42
			var outer_a: float = section.half_width(a)+section.rail_setback(a,side)+1.3
			var outer_b: float = section.half_width(b)+section.rail_setback(b,side)+1.3
			var points := [section.point(a,side*left)-Vector3.UP*0.025,section.point(a,side*outer_a)-Vector3.UP*0.025,section.point(b,side*right)-Vector3.UP*0.025,section.point(b,side*outer_b)-Vector3.UP*0.025]
			for bank in range(2):
				if bank == 1:
					points = [points[1],section.scenery.terrain_point(a,side*(outer_a+section.shoulder_bank_span(a,side))),points[3],section.scenery.terrain_point(b,side*(outer_b+section.shoulder_bank_span(b,side)))]
				for index in ([0,2,1,1,2,3] if side > 0 else [0,1,2,1,3,2]):
					st.set_color(Color.WHITE if bank == 1 and section.closed_loop else Color.BLACK)
					st.set_uv(Vector2(points[index].x,points[index].z)/5)
					st.add_vertex(points[index])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "DirtShoulders"
	node.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dirt_shoulder.gdshader")
	material.set_shader_parameter("dirt_texture",preload("res://assets/environment/dirt-shoulder.png"))
	material.set_shader_parameter("grass_texture",preload("res://assets/environment/lakeside-grass.png"))
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	section.add_child(node)

static func markings(section: Node3D, samples: Array[float]) -> void:
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	curb.set_smooth_group(0)
	var profile := [Vector2(-0.25,0.015),Vector2(-0.15,0.13),Vector2(0.35,0.13),Vector2(0.45,0.015)]
	for side in [-1.0,1.0]:
		for i in range(samples.size()-1):
			var a := samples[i]
			var b := samples[i+1]
			if a < 150 and side == -section.entry_side: continue
			if not section.closed_loop and section.rail_setback(a,side) > 2.3: continue
			for band in range(3):
				var points := [section.point(a,side*(section.half_width(a)+profile[band].x))+Vector3.UP*profile[band].y,section.point(a,side*(section.half_width(a)+profile[band+1].x))+Vector3.UP*profile[band+1].y,section.point(b,side*(section.half_width(b)+profile[band].x))+Vector3.UP*profile[band].y,section.point(b,side*(section.half_width(b)+profile[band+1].x))+Vector3.UP*profile[band+1].y]
				for index in ([0,2,1,1,2,3] if side > 0 else [0,1,2,1,3,2]):
					curb.set_uv(Vector2(0,a if index < 2 else b))
					curb.add_vertex(points[index])
	curb.index()
	curb.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "CurvedCurbs"
	node.mesh = curb.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/curb_paint.gdshader")
	material.set_shader_parameter("red_color",Color("c94c48"))
	material.set_shader_parameter("white_color",Color("e9e7db"))
	node.material_override = material
	section.add_child(node)
	var lanes := SurfaceTool.new()
	lanes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for center in [-0.5,0.0,0.5]:
		for i in range(samples.size()-1):
			var a := samples[i]
			var b := samples[i+1]
			var la: float = section.half_width(a)*center
			var lb: float = section.half_width(b)*center
			var points := [section.point(a,la-0.055),section.point(a,la+0.055),section.point(b,lb-0.055),section.point(b,lb+0.055)]
			for index in [0,2,1,1,2,3]:
				lanes.set_uv(Vector2(0,a if index < 2 else b))
				lanes.add_vertex(points[index]+Vector3.UP*0.027)
	lanes.generate_normals()
	var paint := MeshInstance3D.new()
	paint.name = "CurvedLaneMarks"
	paint.mesh = lanes.commit()
	var lane_material := ShaderMaterial.new()
	lane_material.shader = preload("res://shaders/lane_dash.gdshader")
	paint.material_override = lane_material
	paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	section.add_child(paint)
