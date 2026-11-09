extends RefCounted
# The physics surface uses the same triangles as the visible road and apron.
# Road and barriers use separate static bodies and collision layers.
static func body(label: String, faces: PackedVector3Array, layer: int) -> StaticBody3D:
	var node := StaticBody3D.new()
	node.name = label
	node.collision_layer = layer
	node.collision_mask = 4
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	node.add_child(collision)
	return node
static func append_mesh(out: PackedVector3Array, mesh: Mesh, transform: Transform3D) -> void:
	for p in mesh.get_faces(): out.append(transform*p)
static func append_box(out: PackedVector3Array, transform: Transform3D, template: BoxMesh) -> void:
	append_mesh(out,template,transform)
static func frame(section: Node3D, d: float) -> Basis:
	var forward: Vector3 = (section.point(d+1)-section.point(d-1)).normalized()
	var right: Vector3 = (section.point(d,1)-section.point(d,-1)).normalized()
	var up := right.cross(forward).normalized()
	return Basis(forward.cross(up).normalized(),up,-forward).orthonormalized()
static func build(section: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "FujiWorldCollision"
	var ground := PackedVector3Array()
	var walls := PackedVector3Array()
	var relative: Transform3D = section.global_transform.affine_inverse()
	# Read only authored drivable geometry. Water and decorative terrain do not
	# create a phantom horizontal floor across the bridge or beneath a tunnel.
	for child in section.get_children():
		if child is MeshInstance3D and (child == section.road_surface or child.name == "RoadBase" or child.name == "DirtShoulders" or child.get_meta("world_ground",false)):
			append_mesh(ground,child.mesh,relative*child.global_transform)
	collect_scenery(section.scenery,section,ground,walls)
	var trucks := PackedVector3Array()
	for child in section.get_children():
		if child.get_meta("parked_truck",false):
			for part in child.get_children():
				if part is MeshInstance3D: append_mesh(trucks,part.mesh,relative*part.global_transform)
	if not trucks.is_empty():
		var truck_body := body("ParkedTruckBody",trucks,2)
		truck_body.set_meta("parked_truck",true)
		root.add_child(truck_body)
	var template := BoxMesh.new()
	template.size = Vector3.ONE
	# Straight stretches use 8 m boxes (every car sweeps against the wall mesh each frame, so fewer
	# triangles are cheaper). On bends a long straight box would leave the curved rail by
	# (L/2)^2/(2R), so tight bends keep 4 m boxes and the tightest 2 m ones.
	var d := 0.0
	while d < section.length:
		var bend: float = absf(wrapf(section.heading(d+10)-section.heading(d-10),-PI,PI))/20.0
		var step := 8.0 if bend < 0.004 else (4.0 if bend < 0.012 else 2.0)
		step = minf(step,section.length-d)
		var middle := d+step*0.5
		var basis := frame(section,middle)
		for side in [-1.0,1.0]:
			if not section.closed_loop and middle < 150 and side == -section.entry_side: continue
			var lane: float = side*(section.half_width(middle)+section.rail_setback(middle,side))
			append_box(walls,Transform3D(basis.scaled_local(Vector3(0.30,1.45,step+0.35)),section.point(middle,lane)+basis.y*0.65),template)
		d += step
	root.add_child(body("RoadSurfaceBody",ground,1))
	root.add_child(body("BarrierBody",walls,2))
	root.set_meta("ground_triangles",ground.size()/3)
	root.set_meta("barrier_triangles",walls.size()/3)
	return root
static func collect_scenery(node: Node, section: Node3D, ground: PackedVector3Array, walls: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.get_meta("world_ground",false):
		append_mesh(ground,node.mesh,section.global_transform.affine_inverse()*node.global_transform)
	if node is MultiMeshInstance3D and node.get_meta("world_barrier",false):
		var parent_frame: Transform3D = section.global_transform.affine_inverse()*node.global_transform
		# Keep authored transforms on the CPU. The headless rendering server
		# returns identity for MultiMesh readback and must not define physics.
		var transforms: Array = node.get_meta("collision_transforms",[])
		for instance_frame: Transform3D in transforms:
			append_mesh(walls,node.multimesh.mesh,parent_frame*instance_frame)
	for child in node.get_children(): collect_scenery(child,section,ground,walls)
