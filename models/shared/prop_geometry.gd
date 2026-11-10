extends RefCounted
# 모델 선택 없이 치수·색상·UV만 처리하는 공통 기하 API.
static func box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, yaw: float = 0, facade: int = -1) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	append(st,mesh,Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),center),color,facade)
static func round_part(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 9
	mesh.rings = 4
	append(st,mesh,Transform3D(Basis.IDENTITY.scaled(size),center),color)
static func column(st: SurfaceTool, center: Vector3, height: float, bottom: float, top: float, color: Color, sides: int = 7) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.radial_segments = sides
	mesh.rings = 1
	append(st,mesh,Transform3D(Basis.IDENTITY,center),color)
static func append(st: SurfaceTool, mesh: Mesh, transform: Transform3D, color: Color, facade: int = -1) -> void:
	var data := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var normal_basis := transform.basis.inverse().transposed()
	for i in range(indices.size() if not indices.is_empty() else vertices.size()):
		var index: int = indices[i] if not indices.is_empty() else i
		st.set_color(color)
		var v := vertices[index]
		var n := normals[index]
		st.set_uv(Vector2(v.z+.5,.5-v.y) if absf(n.x)>.5 else Vector2((.5-v.x) if n.z>0 else (v.x+.5),.5-v.y))
		st.set_uv2(Vector2(10+facade,(2 if absf(n.z)>.5 else 0) if facade>=50 else (1 if n.z>.5 else 0)) if facade>=0 and absf(n.y)<.5 else Vector2.ZERO)
		st.set_normal((normal_basis*normals[index]).normalized())
		st.add_vertex(transform*vertices[index])
static func metre_mesh(source: ArrayMesh, factor: Vector3, target_height: float = 0.0) -> ArrayMesh:
	if target_height > 0: factor = Vector3.ONE*target_height/source.get_aabb().size.y
	if factor == Vector3.ONE: return source
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		vertices[i] *= factor
		normals[i] = (normals[i]/factor).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in range(vertices.size()):
			var tangent := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])*factor
			tangent = (tangent-normals[i]*tangent.dot(normals[i])).normalized()
			tangents[i*4] = tangent.x
			tangents[i*4+1] = tangent.y
			tangents[i*4+2] = tangent.z
		arrays[Mesh.ARRAY_TANGENT] = tangents
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.surface_set_material(0,source.surface_get_material(0))
	return result

static func architectural_mass(st: SurfaceTool, size: Vector3, offset: Vector3 = Vector3.ZERO, floors: int = 1, columns: int = 3) -> void:
	# 외벽 이미지를 평면 카드로 두지 않고 기단·모서리 기둥·깊은 창턱을 실제 메시로 만든다.
	var stone := Color("797971")
	var trim := Color("b2aaa0")
	box(st,offset+Vector3.UP*.22,Vector3(size.x+.65,.44,size.z+.65),stone)
	box(st,offset+Vector3.UP*.52,Vector3(size.x+.2,.2,size.z+.2),stone.lightened(.12))
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			box(st,offset+Vector3(x*(size.x*.5-.05),size.y*.5,z*(size.z*.5-.05)),Vector3(.34,size.y,.34),trim)
	box(st,offset+Vector3(0,size.y-.12,0),Vector3(size.x+.35,.28,size.z+.35),trim.darkened(.15))
	for floor_index in range(floors):
		var y: float = (floor_index+.22)*size.y/floors+.45
		for column_index in range(columns):
			var x: float = -size.x*.5+(column_index+.5)*size.x/columns
			var w: float = size.x/columns*.76
			box(st,offset+Vector3(x,y,size.z*.5+.12),Vector3(w,.16,.48),stone)
			if floors > 1:
				box(st,offset+Vector3(x,y+2.1,size.z*.5+.09),Vector3(w,.18,.34),trim)
				for side in [-1.0,1.0]: box(st,offset+Vector3(x+side*w*.5,y+1,size.z*.5+.08),Vector3(.13,2.1,.24),trim)
				box(st,offset+Vector3(x,y,size.z*.5+.6),Vector3(w+.2,.22,1.25),stone)
				box(st,offset+Vector3(x,y+.95,size.z*.5+1.1),Vector3(w+.2,.09,.09),Color("444c4e"))
				for bar in range(3): box(st,offset+Vector3(x+(bar-1)*w*.4,y+.48,size.z*.5+1.1),Vector3(.055,.9,.055),Color("444c4e"))
