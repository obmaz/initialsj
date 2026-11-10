extends Node3D
# Place regional solid models outside the road using each model's full bounding radius.
const Props = preload("res://scripts/regional_props_3d.gd")
var scenery: Node3D
var positions: Array[Vector3] = []
var widths: Array[float] = []
var models: Node3D
func _ready() -> void:
 var theme: String = scenery.theme
 var road: Node3D = scenery.track
 var random := RandomNumberGenerator.new()
 random.seed = 2026+road.stage*137+road.route_node*47
 var placements: Array[Dictionary] = []
 var family: Array = Props.FAMILIES[theme]
 var spacing := 44.0 if theme in ["city","seoul","neon","harbor"] else (72.0 if theme in ["ruins","canyon"] else 36.0)
 var count := int((road.length-500)/spacing)
 for i in range(count):
  var d: float = 240+i*spacing+random.randf_range(-5,5)
  if road.in_tunnel(d): continue
  if road.bridge_span.y > road.bridge_span.x and d > road.bridge_span.x-65 and d < road.bridge_span.y+65: continue
  var side := -1.0 if i%2 == 0 else 1.0
  if road.entry_side != 0 and d < 650: side = float(road.entry_side)
  if theme in ["hawaii","jeju","fuji"]: side = 1.0
  var variant := i%family.size()
  var kind: String = family[variant]
  var scale: float = Props.placement_scale(kind,random.randf_range(0.8,1.25))
  var radius: float = Props.radius(kind)*scale
  # Stone guardians stand right at the roadside so they are seen; other props spread out.
  var lane: float = side*(road.half_width(d)+road.rail_setback(d,side)+2.6+radius+random.randf_range(0,3 if kind == "hareubang" else 11))
  if theme == "canyon": lane += side*12
  var p: Vector3 = road.roadside_point(d,lane)
  var closest: float = road.curve.get_closest_offset(p)
  var center: Vector3 = road.point(closest)
  if Vector2(p.x-center.x,p.z-center.z).length()-radius < road.half_width(closest)+road.rail_setback(closest,side)+1.5: continue
  positions.append(p)
  widths.append(radius*2)
  var yaw: float = road.heading(d)+side*PI*0.5+random.randf_range(-0.2,0.2) if kind == "hareubang" else road.heading(d)+random.randf_range(-0.35,0.35)
  if kind in ["coffee_shop","souvenir_shop","street_shop","convenience_store","apartment","gas_station","warehouse_shed"]: yaw = road.heading(d)-side*PI*.5
  placements.append({"position":p,"yaw":yaw,"scale":scale,"variant":variant})
  if kind in ["palm","broadleaf","pine","snow_pine","sakura","bamboo","plane_tree","ginkgo","japanese_pine"]: scenery.tree_positions.append(p)
 models = Props.new()
 models.name = "RegionalForeground3D"
 models.configure(theme,placements)
 add_child(models)
