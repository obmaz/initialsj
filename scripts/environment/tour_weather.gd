extends Node3D
const RaceState = preload("res://scripts/race/race_state.gd")
var race: Node
var particles: CPUParticles3D
var current_weather := ""
func _ready() -> void:
 particles=CPUParticles3D.new()
 particles.emitting=false
 particles.local_coords=false
 particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
 particles.emission_box_extents=Vector3(18,8,25)
 var mat:=StandardMaterial3D.new()
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
 var fade:=Gradient.new()
 fade.set_color(0,Color(1,1,1,.65))
 fade.set_color(1,Color(1,1,1,0))
 var soft:=GradientTexture2D.new()
 soft.gradient=fade
 soft.width=16
 soft.height=16
 soft.fill=GradientTexture2D.FILL_RADIAL
 soft.fill_from=Vector2(.5,.5)
 soft.fill_to=Vector2(1,.5)
 mat.albedo_texture=soft
 particles.material_override=mat
 add_child(particles)
func configure(weather: String) -> void:
 current_weather=weather
 particles.emitting=false
 if weather == "clear": return
 var rain:=weather == "rain"
 var snow:=weather == "snow"
 particles.amount=360 if rain else (180 if snow else 200)
 particles.lifetime=1.6 if rain else 3.2
 particles.direction=Vector3(.1,-1,0) if rain else (Vector3(.35,-.8,.1) if snow else Vector3(1,.08,.2))
 particles.gravity=Vector3(0,-4,0) if rain else Vector3(0,-.3,0)
 particles.initial_velocity_min=22 if rain else (2 if snow else 5)
 particles.initial_velocity_max=30 if rain else (4 if snow else 10)
 particles.spread=12 if rain else 35
 particles.color=Color(.64,.76,.86,.7) if rain else (Color(.95,.98,1,.8) if snow else Color(.78,.63,.37,.26))
 var mesh:=QuadMesh.new()
 mesh.size=Vector2(.085,1.7) if rain else (Vector2(.16,.16) if snow else Vector2(.7,.3))
 particles.mesh=mesh
 particles.restart()
func _process(_delta: float) -> void:
 if race.mode != "tour" or race.state not in RaceState.DRIVING or not race.track.visible:
  particles.emitting=false
  return
 var road: Node3D=race.track.active
 var weather: String=road.region_metadata.get("weather","clear")
 if weather != current_weather: configure(weather)
 var at: float=road.curve.get_closest_offset(race.player.global_position)
 particles.emitting=weather != "clear" and not road.in_tunnel(at) and not race.motion_reduced
 var camera: Camera3D=get_viewport().get_camera_3d()
 # 이 노드는 실제 레이스 SubViewport 안에 둔다.
 if camera != null: global_position=camera.global_position-camera.global_basis.z*15+Vector3.UP*6
 else: global_position=race.player.global_position+Vector3.UP*7
