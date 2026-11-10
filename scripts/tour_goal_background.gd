extends Node3D
const THEMES := ["canyon","harbor","bamboo","snow","volcano"]
const IMAGES := ["res://assets/environment/goal-canyon.png","res://assets/environment/goal-harbor.png","res://assets/environment/goal-bamboo.png","res://assets/environment/goal-snow.png","res://assets/environment/goal-volcano.png"]
var race: Node
var route_id := -1
var road_id := 0
func _process(_delta: float) -> void:
 if race.mode != "tour" or race.track.active.stage != 4 or race.atmosphere.sky == null: return
 var road: Node3D = race.track.active
 if route_id == road.route_node and road_id == road.get_instance_id(): return
 route_id = road.route_node
 road_id = road.get_instance_id()
 var material := ShaderMaterial.new()
 material.shader = preload("res://shaders/tour_goal_sky.gdshader")
 material.set_shader_parameter("panorama",load(IMAGES[route_id]))
 material.set_shader_parameter("cloudiness",1.0 if road.region_metadata.get("weather","") == "rain" else 0.0)
 # 파노라마 중심을 골 직전 접선 방향에 고정한다. 카메라 회전에 따라 사진을 따라 돌리지 않는다.
 var forward: Vector3 = (road.point(road.length-25)-road.point(road.length-60)).normalized()
 material.set_shader_parameter("heading",atan2(forward.x,forward.z))
 race.atmosphere.sky.sky_material = material
