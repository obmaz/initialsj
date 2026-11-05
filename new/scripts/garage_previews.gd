extends Node
const Car = preload("res://scripts/car.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
var textures: Array[Texture2D] = []
func _ready() -> void:
	for i in range(3):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(560,300)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var world := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0,0,0,0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("dceaff")
		env.ambient_light_energy = 0.65
		world.environment = env
		viewport.add_child(world)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35,-35,0)
		sun.light_energy = 1.4
		viewport.add_child(sun)
		var car := Car.new()
		var profile := Catalog.spec(i)
		car.model = profile.model
		car.paint = Color(profile.paint)
		car.nitro_tint = Color(profile.accent)
		viewport.add_child(car)
		var camera := Camera3D.new()
		camera.position = Vector3(-3.2,1.8,-4.3)
		camera.fov = 30
		viewport.add_child(camera)
		camera.look_at(Vector3(0,0.65,0))
		textures.append(viewport.get_texture())
