extends Node3D
const Architecture = preload("res://scripts/environment/urban_architecture.gd")
const Library = preload("res://scripts/track/route_library.gd")
var track: Node3D
var theme := "hawaii"
var rng := RandomNumberGenerator.new()
var batches: Array[MultiMeshInstance3D] = []
var rotating: Array[Node3D] = []
var tree_positions: Array[Vector3] = []
var ground_nodes: Array[MeshInstance3D] = []
var roadside_art: Node3D
var distant_art: Node3D
var local_lights: Array[OmniLight3D] = []
var building_manifest: Array[Dictionary] = []
var landmarks: Node3D
var water: MeshInstance3D
const RenderResources = preload("res://scripts/rendering/render_resources.gd")
const OCEAN_RIPPLES = "res://assets/environment/ocean-ripples.png"

const TERRAIN_VARIANTS = "res://assets/environment/terrain-variants.png"
const DETAILED_THEMES := ["jungle", "pyramid", "snow", "hawaii", "jeju", "fuji", "bamboo", "amusement"]


static func region_variants_path(region: String) -> String:
	if region == "pyramid":
		return "res://assets/environment/tour-sand-variants.png"
	return (
		"res://assets/environment/tour-snow-variants.png"
		if region == "snow"
		else "res://assets/environment/tour-grass-variants.png"
	)


# 이 지역이 처음 쓰는 텍스처·모델. 주행 중에 만드는 구간은 생성 첫 단계에서 미리 읽기 시작한다.
static func warm_paths(region: String) -> Array[String]:
	var paths: Array[String] = [TERRAIN_VARIANTS, preload("res://scripts/environment/tour_goal_background.gd").CLOUDS]
	var goal_index: int = preload("res://scripts/environment/tour_goal_background.gd").THEMES.find(region)
	if goal_index >= 0:
		paths.append(preload("res://scripts/environment/tour_goal_background.gd").IMAGES[goal_index])
	if region in DETAILED_THEMES:
		paths.append(region_variants_path(region))
	if Library.coastal(region):
		paths.append(OCEAN_RIPPLES)
	if preload("res://scripts/environment/distant_ridges.gd").THEMES.has(region):
		paths.append(preload("res://scripts/environment/distant_ridges.gd").ATLAS_PATH)
	paths.append_array(preload("res://scripts/environment/tour_vegetation.gd").warm_paths(region))
	if region in ["city", "seoul", "ruins", "neon"]:
		paths.append_array([Architecture.FACADE_IMAGES, Architecture.FACADE_EXTRA, Architecture.STRUCTURE_IMAGES])
		paths.append_array([Architecture.Variants.URBAN_A, Architecture.Variants.URBAN_B])
	if region == "jungle":
		paths.append(preload("res://scripts/environment/jungle_overgrowth.gd").ROCK)
	return paths


func terrain_point(d: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(d, lane)
	var road_y: float = track.point(d).y
	if theme == "harbor" and lane >= -(track.half_width(d) + 71):
		p.y = road_y - 0.3
	elif Library.coastal(theme) and lane < -(track.half_width(d) + (71 if theme == "harbor" else 1)):
		p.y = lerpf(
			0.12, road_y - 0.3, clampf((lane + track.half_width(d) + (80 if theme == "harbor" else 10)) / 9, 0, 1)
		)
	elif theme in ["hawaii", "jeju"] and lane > 18:
		var rise := smoothstep(30, 160, lane) * (1 - smoothstep(190, 260, lane))
		var folds := 12 + 8 * sin(d * 0.003 + lane * 0.008) + 5 * cos(d * 0.008 - lane * 0.012)
		p.y = road_y - 0.3 + rise * folds
	else:
		var rise := pow(clampf((absf(lane) - 18) / 140, 0, 1), 1.5)
		p.y = (
			road_y
			- 0.3
			+ rise * (10 if theme in ["pyramid", "canyon", "volcano"] else 5) * sin(d * 0.012 + lane * 0.035)
		)
	var edge_blend := smoothstep(20, 75, absf(lane))
	if theme == "pyramid":
		var dune := .5 + .5 * sin(p.x * .021 + p.z * .009 + sin(p.z * .007))
		p.y += edge_blend * (dune * dune * 18 + pow(.5 + .5 * sin(p.z * .027 - p.x * .013), 2) * 7)
	elif theme == "snow":
		p.y += edge_blend * (3 + 3 * sin(p.x * .016) * cos(p.z * .011))
	elif theme in ["hawaii", "jeju", "fuji", "bamboo", "amusement", "jungle"]:
		p.y += edge_blend * 3 * sin(p.x * .012 + p.z * .006) * cos(p.z * .009)
	if theme == "jungle":
		p.y += track.jungle_cut_depth(d) * smoothstep(15, 38, absf(lane))
	if theme == "amusement" and lane < -40:
		var flat := smoothstep(600, 750, d) * (1 - smoothstep(1700, 1850, d)) * (1 - smoothstep(-110, -40, lane))
		p.y = lerpf(p.y, track.point(1120).y - .3, flat)
	if track.bridge_span.y > track.bridge_span.x:
		var bay := (
			smoothstep(track.bridge_span.x - 65, track.bridge_span.x + 25, d)
			* (1 - smoothstep(track.bridge_span.y - 25, track.bridge_span.y + 65, d))
		)
		p.y = lerpf(p.y, -1.0, bay)
	return p


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")


func ground_lane(d: float, lane: float) -> float:
	return (
		lane + signf(lane) * (track.half_width(d) - 9)
		if absf(lane) <= 19 or (theme == "harbor" and lane == -80)
		else lane
	)


func set_ground_enabled(enabled: bool) -> void:
	for node in ground_nodes:
		node.visible = enabled
	if water != null:
		water.visible = enabled
	if distant_art != null:
		distant_art.visible = enabled


func tunnel_profile(d: float) -> Array[Vector3]:
	var w: float = track.half_width(d) + 2.4
	var points: Array[Vector3] = [track.point(d, -w)]
	for i in range(17):
		var a := PI * i / 16
		points.append(track.point(d, -cos(a) * w) + Vector3.UP * (3.2 + sin(a) * 5))
	points.append(track.point(d, w))
	return points


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		for light in local_lights:
			light.visible = light.global_position.distance_to(camera.global_position) < light.omni_range + 40
	for node in rotating:
		node.rotate_object_local(Vector3.FORWARD, delta * 0.16)
