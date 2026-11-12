extends Node3D
# 형상·배치는 저장 씬, 가까운 실제 광원과 코스별 재질 상태만 이 제어기가 소유한다.
const RaceState = preload("res://scripts/race/race_state.gd")
const MATERIALS := [
	"fixture_lamp.gdshader",
	"billboard_ad.gdshader",
	"prop_advertisement.gdshader",
	"speedway_wall_ad.gdshader",
	"road_paint.gdshader"
]
var street_lights: Array[Transform3D] = []
var billboard_lights: Array[Transform3D] = []
var street_spacing := 0.0
var street_pools: Texture2D
var race: Node3D
var is_night := false
var lights: Array[SpotLight3D] = []
var selection_clock := 0.0
var local_materials: Dictionary = {}


func _ready() -> void:
	for i in range(4):
		var light := SpotLight3D.new()
		light.name = "NearbyLight%d" % i
		light.visible = false
		light.shadow_enabled = false
		light.spot_angle_attenuation = 1.3
		add_child(light)
		lights.append(light)


func configure(owner: Node3D) -> void:
	race = owner
	is_night = race.track_environment.active_period != "day"
	var wet: bool = race.track_environment.active_weather == "rain"
	var road: Node3D = race.track.active
	var changed := {}
	for node in preload("res://scripts/rendering/world_assets.gd").nodes(road):
		if node.is_in_group("racing_advertisement"):
			node.set_meta("advertisement_night", is_night)
		if not node is GeometryInstance3D or not node.material_override is ShaderMaterial:
			continue
		var material: ShaderMaterial = node.material_override
		if material.shader == null or material.shader.resource_path.get_file() not in MATERIALS:
			continue
		if not node.has_meta(&"course_private_material") or node.get_meta(&"course_private_material") != material:
			var id := material.get_instance_id()
			if not local_materials.has(id):
				local_materials[id] = material.duplicate()
			material = local_materials[id]
			node.material_override = material
			node.set_meta(&"course_private_material", material)
		if changed.has(material.get_instance_id()):
			continue
		changed[material.get_instance_id()] = true
		if material.shader.resource_path.get_file() == "road_paint.gdshader":
			material.set_shader_parameter("rain_wetness", 1.0 if wet else 0.0)
		else:
			material.set_shader_parameter("night_lighting", 1.0 if is_night else 0.0)
	road.road_surface.material_override.set_shader_parameter("street_spacing", street_spacing)
	road.road_surface.material_override.set_shader_parameter("street_pool_lookup", street_pools)
	road.road_surface.material_override.set_shader_parameter("course_length", road.length)
	road.road_surface.material_override.set_shader_parameter(
		"street_lighting", (0.5 if road.course_id == 1 else .23) if is_night else 0.0
	)
	selection_clock = 0


func _process(delta: float) -> void:
	if race == null:
		return
	if not is_night or not race.track.visible or race.state not in RaceState.DRIVING:
		for light in lights:
			light.visible = false
		return
	selection_clock -= delta
	if selection_clock > 0:
		return
	selection_clock = .15
	var capacity: int = [4, 3, 2][race.render_budget.level]
	var camera_position: Vector3 = race.camera.global_position
	var candidates: Array[Dictionary] = []
	for kind in range(2):
		var anchors: Array[Transform3D] = street_lights if kind == 0 else billboard_lights
		for anchor in anchors:
			var gap := camera_position.distance_squared_to(anchor.origin)
			if gap < (95.0 * 95.0 if kind == 0 else 72.0 * 72.0):
				candidates.append({"anchor": anchor, "score": gap, "ad": kind == 1})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.score < b.score)
	var selected: Array[Dictionary] = []
	var ads_used := 0
	for candidate in candidates:
		if candidate.ad and not street_lights.is_empty() and ads_used >= 1:
			continue
		selected.append(candidate)
		if candidate.ad:
			ads_used += 1
		if selected.size() >= capacity:
			break
	for i in range(lights.size()):
		var light := lights[i]
		light.visible = i < selected.size()
		if not light.visible:
			continue
		var item: Dictionary = selected[i]
		light.global_transform = item.anchor
		light.spot_range = 22 if item.ad else 62
		light.spot_angle = 56 if item.ad else 58
		light.light_energy = 4.2 if item.ad else (7.5 if race.selected_course == 1 else 5.0)
		light.light_color = Color("fff1d6") if item.ad else Color("ffe7bd")


func _exit_tree() -> void:
	local_materials.clear()
	race = null
