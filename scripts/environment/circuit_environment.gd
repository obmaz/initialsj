extends Node3D

const PANORAMA = preload("res://assets/environment/fuji-lake-panorama.png")
const BACK_A = preload("res://assets/environment/fuji-lake-back-a.png")
const BACK_B = preload("res://assets/environment/fuji-lake-back-b.png")
const SKY_SHADER = preload("res://shaders/fuji_sky.gdshader")
const WATER_HEIGHT := 0.0
const SHORE_LANE := -18.0
var theme := "fuji"
var track: Node3D
var landmarks: Node3D
var water: MeshInstance3D
var tree_positions: Array[Vector3] = []
var tree_batches: Array[MultiMeshInstance3D] = []
var rng := RandomNumberGenerator.new()


func make_sky() -> Sky:
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("panorama", PANORAMA)
	mat.set_shader_parameter("back_a", BACK_A)
	mat.set_shader_parameter("back_b", BACK_B)
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky


func terrain_point(distance: float, lane: float) -> Vector3:
	var p: Vector3 = track.point(distance, lane)
	var road_y: float = track.ground_height(distance)
	if lane < -10:
		p.y = lerpf(WATER_HEIGHT + 0.12, road_y - 0.25, clampf((lane - SHORE_LANE) / (-10.0 - SHORE_LANE), 0, 1))
	else:
		p.y = road_y - 0.25 + maxf(0, lane - 12) * 0.03
	return p


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "코스 모델 씬으로 생성해야 한다")
