extends Node3D
const Catalog = preload("res://models/model_catalog.gd")
const LEAVES = "res://models/shared/foliage/tree-leaves.webp"
const BARK = "res://models/shared/foliage/bark.webp"
const NEEDLES = "res://models/shared/foliage/needle-sprays.webp"
var scenery: Node3D
var tree_count := 0
var variant_counts := {}
func _ready() -> void:
 var theme: String = scenery.theme
 if theme in ["desert","pyramid","canyon","volcano","harbor"]: return
 var definitions: Array[Resource] = Catalog.all("vegetation")
 var groups := {}
 var pieces := {}
 var road: Node3D = scenery.track
 var spacing := 24 if theme in ["amusement","fuji","bamboo","snow"] else 42
 for i in range(int((road.length-360)/spacing)):
  var d := 180.0+i*spacing
  if road.in_tunnel(d): continue
  if road.bridge_span.y > road.bridge_span.x and d > road.bridge_span.x-80 and d < road.bridge_span.y+80: continue
  var v := (i%3)+2 if theme in ["snow","bamboo"] else i%7
  if theme in ["hawaii","jeju"]: v = (5+i%2) if i%7 >= 5 else i%2
  if theme in ["snow","bamboo"] and i%7 >= 5: v = 5+i%2
  var item: Resource = definitions[v]
  var side := 1.0 if theme in ["hawaii","jeju","fuji"] else (-1.0 if i%2 else 1.0)
  var lane: float = side*(road.half_width(d)+road.rail_setback(d,side)+12+(i%4)*6)
  var point: Vector3 = road.roadside_point(d,lane)
  var nearest: float = road.curve.get_closest_offset(point)
  if point.distance_to(road.point(nearest)) < road.half_width(nearest)+12: continue
  var key := str(v)+":"+str(floori(point.x/120))+":"+str(floori(point.z/120))
  if not groups.has(key): groups[key] = {"variant":v,"poses":[]}
  groups[key].poses.append(Transform3D(Basis(Vector3.UP,i*2.399),point))
  variant_counts[item.id] = int(variant_counts.get(item.id,0))+1
  tree_count += 1
 if theme == "amusement":
  for park in scenery.get_children():
   if park.get_script() != preload("res://scripts/tour_amusement.gd"): continue
   for i in range(12):
    var v := i%5
    var point: Vector3 = park.to_global(Vector3(-70+(i%6)*28,0,52 if i < 6 else -106))
    var key := str(v)+":"+str(floori(point.x/120))+":"+str(floori(point.z/120))
    if not groups.has(key): groups[key] = {"variant":v,"poses":[]}
    groups[key].poses.append(Transform3D(Basis(Vector3.UP,i*2.399),point))
    variant_counts[definitions[v].id] = int(variant_counts.get(definitions[v].id,0))+1
    tree_count += 1
 for key in groups:
  var group: Dictionary = groups[key]
  var item: Resource = definitions[group.variant]
  if not pieces.has(group.variant):
   var resource: Resource = load(item.source_mesh_path)
   var mesh: Mesh
   if resource is PackedScene:
    var scene: Node = resource.instantiate()
    mesh = preload("res://models/shared/scene_source.gd").collect_meshes(scene)[0].mesh
    scene.free()
   else: mesh = resource
   var scale: float = item.parameters.height/mesh.get_aabb().size.y
   pieces[group.variant] = []
   for surface in range(mesh.get_surface_count()):
    var leaf: bool = mesh.surface_get_material(surface).resource_name.begins_with("LeafSprays")
    var part := ArrayMesh.new()
    part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(surface))
    var material := StandardMaterial3D.new()
    material.albedo_texture = load(BARK if not leaf else (NEEDLES if item.parameters.needles else LEAVES))
    material.vertex_color_use_as_albedo = true
    material.roughness = .96
    if leaf:
     material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
     material.alpha_scissor_threshold = .28 if item.parameters.needles else .42
     material.cull_mode = BaseMaterial3D.CULL_DISABLED
    pieces[group.variant].append({"mesh":part,"material":material,"scale":scale})
  for piece in pieces[group.variant]:
   var part: ArrayMesh = piece.mesh
   var material: Material = piece.material
   var scale: float = piece.scale
   for start in range(0,group.poses.size(),12):
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = part
    multi.instance_count = mini(12,group.poses.size()-start)
    for j in range(multi.instance_count):
     multi.set_instance_transform(j,group.poses[start+j].scaled_local(Vector3.ONE*scale))
     multi.set_instance_color(j,Color.WHITE)
    var node := MultiMeshInstance3D.new()
    node.multimesh = multi
    node.material_override = material
    node.visibility_range_end = 100 if group.variant >= 5 else 240
    node.visibility_range_end_margin = 25
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
