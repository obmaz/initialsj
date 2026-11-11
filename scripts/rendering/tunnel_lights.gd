extends Node3D
# Three real fixture families with a shared nearest-light budget for WebGL.
const MAX_NEARBY := 6
const UPDATE_PERIOD := 0.06
static var pipeline_warmed := false
var update_clock := 0.0
var selection_passes := 0
var visibility_changes := 0
var track: Node3D
var span := Vector2.ZERO
var ceiling := 7.0
var lights: Array[Light3D] = []
var families: Array[int] = []
var fixtures := {"rim": [], "warm": [], "cool": [], "amber": []}


func _ready() -> void:
	assert(preload("res://models/shared/scene_state.gd").bind(self), "조명이 포함된 코스 씬으로 생성해야 한다")


func update_lights(at: Vector3) -> void:
	selection_passes += 1
	# Keep only the closest budget entries; never sort every lamp in a long tunnel.
	var nearest: Array[int] = []
	var distances: Array[float] = []
	for i in range(lights.size()):
		var distance := lights[i].global_position.distance_squared_to(at)
		if distance >= 39 * 39:
			continue
		var insertion := 0
		while insertion < distances.size() and distances[insertion] <= distance:
			insertion += 1
		if insertion >= MAX_NEARBY:
			continue
		distances.insert(insertion, distance)
		nearest.insert(insertion, i)
		if nearest.size() > MAX_NEARBY:
			nearest.pop_back()
			distances.pop_back()
	for i in range(lights.size()):
		var wanted := nearest.has(i)
		# Unchanged lamps must not be removed and re-added to the renderer every frame.
		if lights[i].visible != wanted:
			lights[i].visible = wanted
			visibility_changes += 1


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	update_clock -= delta
	if update_clock > 0:
		return
	update_clock = UPDATE_PERIOD
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		update_lights(camera.global_position)


static func collect_rigs(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	if node.get_script() == load("res://scripts/rendering/tunnel_lights.gd"):
		out.append(node)
	for child in node.get_children():
		out.append_array(collect_rigs(child))
	return out


static func prewarm_scene(race: Node3D) -> void:
	if pipeline_warmed or DisplayServer.get_name() == "headless":
		return
	var rigs := collect_rigs(race.track)
	if rigs.is_empty():
		return
	# Run only behind the opaque screen-transition cover. The normal first world
	# frame does not see a tunnel, so it cannot prepare local-light shader variants.
	var rig: Node3D = rigs[0]
	var camera: Camera3D = race.camera
	var saved_transform := camera.global_transform
	var saved_processing: bool = race.is_physics_processing()
	var was_visible: bool = race.track.visible
	race.set_physics_process(false)
	race.track.visible = true
	for offset in [0.0, 28.0, 44.0, 60.0, 76.0]:
		var d: float = minf(rig.span.y - 10, rig.span.x + offset)
		camera.position = rig.track.point(d) + Vector3.UP * 2.3
		camera.look_at(rig.track.point(d + 24) + Vector3.UP * 2.0)
		camera.reset_physics_interpolation()
		rig.update_lights(camera.global_position)
		await race.get_tree().process_frame
		await RenderingServer.frame_post_draw
	camera.global_transform = saved_transform
	camera.reset_physics_interpolation()
	for other in rigs:
		other.update_lights(camera.global_position)
	race.track.visible = was_visible
	race.set_physics_process(saved_processing)
	pipeline_warmed = true
