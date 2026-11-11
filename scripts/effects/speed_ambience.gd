extends Node3D
# Celebration bursts only. Driving has no continuous pollen, petals or dust emitter.
const RaceState = preload("res://scripts/race/race_state.gd")
var petals := CPUParticles3D.new()
var last_checkpoint := 0
var last_state := RaceState.READY


func _ready() -> void:
	petals.amount = 24
	petals.lifetime = 0.7
	petals.one_shot = true
	petals.explosiveness = 1
	petals.emitting = false
	petals.local_coords = false
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(6, 1, 3)
	petals.direction = Vector3.UP
	petals.spread = 80
	petals.initial_velocity_min = 1
	petals.initial_velocity_max = 4
	petals.gravity = Vector3(0, -5, 0)
	var mesh := preload("res://scripts/rendering/render_resources.gd").quad(Vector2(0.12, 0.18))
	petals.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sakura_petal.gdshader")
	material.set_shader_parameter("confetti", 1.0)
	petals.material_override = material
	add_child(petals)


func update(race: Node3D) -> void:
	var celebrate: bool = (
		race.checkpoints > last_checkpoint or (race.state == RaceState.FINISHED and last_state != RaceState.FINISHED)
	)
	last_checkpoint = race.checkpoints
	last_state = race.state
	petals.visible = not race.motion_reduced and race.state in [RaceState.RACING, RaceState.FINISHED]
	if celebrate and petals.visible:
		petals.position = race.track.point(race.distance + 12) + Vector3.UP * 4
		petals.restart()
		petals.emitting = true
	elif race.state not in [RaceState.RACING, RaceState.FINISHED] or race.motion_reduced:
		petals.emitting = false
