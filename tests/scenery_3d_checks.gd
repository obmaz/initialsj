extends RefCounted
const Report = preload("res://tests/report.gd")
const Props = preload("res://scripts/regional_props_3d.gd")
const Library = preload("res://scripts/route_library.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1; push_error(message)
func run(tree: SceneTree) -> int:
 var rows := []
 var all_kinds := {}
 for theme in Props.FAMILIES:
  var placements: Array[Dictionary] = []
  for i in range(3): placements.append({"position":Vector3(i*15,0,0),"variant":i})
  var models := Props.new()
  models.configure(theme,placements)
  tree.root.add_child(models)
  check(models.world_bounds.size() == 3,"Every regional object must expose a real world-space volume")
  check(models.kinds.size() >= 2,"Every region needs more than one foreground silhouette")
  for kind in models.kinds:
   all_kinds[kind] = true
   var mesh := Props.model(kind)
   var bounds := mesh.get_aabb()
   check(bounds.size.x > 1 and bounds.size.z > 0.35 and bounds.size.y > 1,"Foreground meshes must have depth instead of being flat billboards: "+kind)
   var arrays := mesh.surface_get_arrays(0)
   check(arrays[Mesh.ARRAY_INDEX].size()/3 < 3200,"Individual models must remain within the mobile triangle budget: "+kind)
  for batch in models.batches:
   check(not batch.multimesh.mesh is QuadMesh,"Foreground props must not use camera-facing quads")
   check(batch.multimesh.instance_count <= 12,"Spatial groups must have bounded instance counts")
  rows.append({"theme":theme,"silhouettes":models.kinds.duplicate(),"batch_count":models.batches.size()})
  models.queue_free()
  await tree.process_frame
 check(all_kinds.size() >= 18,"The full tour must have a varied regional mesh library")
 var race = load("res://scenes/race.tscn").instantiate()
 tree.root.add_child(race)
 race.set_physics_process(false)
 race.save_records = false
 for choice in [[0,0],[1,1],[2,2],[3,1],[4,2],[4,3]]:
  race.track.reset(choice[0],choice[1])
  var section: Node3D = race.track.active
  var foreground: Node3D = section.scenery.roadside_art
  check(foreground.positions.size() > 20,"Representative routes need a populated regional foreground")
  for i in range(foreground.positions.size()):
   var p: Vector3 = foreground.positions[i]
   var nearest: float = section.curve.get_closest_offset(p)
   var center: Vector3 = section.point(nearest)
   var clearance: float = Vector2(p.x-center.x,p.z-center.z).length()-foreground.widths[i]*0.5-section.half_width(nearest)
   check(clearance > section.rail_setback(nearest,signf((p-center).dot((section.point(nearest,1)-center).normalized())))+1.0,"A foreground object's entire bounding radius must stay beyond the safety rail")
  if section.scenery.theme in ["city","seoul"]:
   var styles := {}
   for building in section.scenery.building_manifest: styles[building.style] = true
   check(styles.size() >= 5,"City regions need several actual architecture silhouettes")
   check(section.scenery.distant_art.has_node("DistantBuildings3D_0") and section.scenery.distant_art.sprite_batch == null,"City skyline must use solid 3D buildings rather than a skyline billboard")
  await tree.process_frame
 race.choose_mode("track",0)
 check(race.track.scenery.has_node("FujiForest3D"),"Fuji needs a solid 3D forest")
 check(race.track.scenery.landmarks.models.kinds.size() >= 3,"Fuji landmarks need distinct solid structures")
 var forest: Node3D = race.track.scenery.get_node("FujiForest3D")
 check(forest.placements.size() > 70 and forest.kinds.has("sakura") and forest.kinds.has("pine"),"Fuji must mix pines and cherry trees")
 FileAccess.open(Report.path("scenery-3d-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify({"regions":rows,"unique_model_kinds":all_kinds.size(),"fuji_tree_count":forest.placements.size(),"failures":failures},"\t")+"\n")
 race.queue_free()
 await tree.process_frame
 print("Regional 3D geometry / silhouettes / clearance / mobile budgets: ","PASS" if failures == 0 else "FAIL")
 return failures
