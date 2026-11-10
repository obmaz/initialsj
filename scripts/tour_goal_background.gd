extends Node3D
const THEMES := ["canyon","harbor","bamboo","snow","volcano"]
const IMAGES := ["res://assets/environment/goal-canyon.png","res://assets/environment/goal-harbor.png","res://assets/environment/goal-bamboo.png","res://assets/environment/goal-snow.png","res://assets/environment/goal-volcano.png"]
const CLOUDS := "res://assets/environment/riviera-sky-panorama.png"
var race: Node
var route_id := -1
var road_id := 0
func _process(_delta: float) -> void:
 if race.mode != "tour" or race.atmosphere.sky == null: return
 var road: Node3D = race.track.active
 if route_id == road.route_node and road_id == road.get_instance_id(): return
 route_id = road.route_node
 road_id = road.get_instance_id()
 var material := ShaderMaterial.new()
 material.shader = preload("res://shaders/tour_goal_sky.gdshader")
 material.set_shader_parameter("cloud_panorama",preload("res://scripts/render_resources.gd").fetch(CLOUDS))
 var goal: bool = road.stage == 4
 material.set_shader_parameter("goal_enabled",goal)
 var period: String = road.region_metadata.get("time_of_day","day")
 var tint := Color(.09,.11,.22) if period == "night" else (Color(.95,.83,.73) if period == "dawn" else Color.WHITE)
 material.set_shader_parameter("sky_tint",Color.WHITE if goal else tint)
 if goal: material.set_shader_parameter("panorama",preload("res://scripts/render_resources.gd").fetch(IMAGES[route_id]))
 material.set_shader_parameter("cloudiness",1.0 if road.region_metadata.get("weather","") == "rain" else 0.0)
 var forward: Vector3 = (road.point(road.length-25)-road.point(road.length-60)).normalized()
 material.set_shader_parameter("heading",atan2(forward.x,forward.z))
 race.atmosphere.sky.sky_material = material
