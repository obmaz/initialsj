extends Node3D
# 측정선의 순방향 통과만 기록한다. 표시·플래시는 해당 구간이 소유하고 파일을 쓰지 않는다.
const Pool = preload("res://scripts/rendering/render_resources.gd")
const Props = preload("res://scripts/environment/regional_props_3d.gd")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
const REVEAL_DELAY := .85
var road: Node3D
var capture_distance := 0.0
var display_distance := 0.0
var previous_distance := -1.0
var previous_speed := 0.0
var previous_eligible := false
var captured_lap := -1
var pending_speed := -1
var displayed_speed := -1
var capture_count := 0
var reveal_left := 0.0
var flash_left := 0.0
var number: Label3D
var flash: MeshInstance3D


static func instance(id: String) -> Node3D:
	var definition: Resource = preload("res://models/prop_models.gd").definition(id)
	return Pool.fetch(definition.scene_path).instantiate()


static func road_pose(section: Node3D, distance: float, lane: float = 0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, section.heading(distance)), section.point(distance, lane))


func configure(section: Node3D, at: float) -> void:
	road = section
	capture_distance = at
	display_distance = at + 180
	var camera := instance("speed_camera")
	camera.name = "SpeedCamera"
	camera.transform = road_pose(road, at, road.half_width(at) + road.rail_setback(at, 1) + 2.0)
	add_child(camera)
	flash = MeshInstance3D.new()
	flash.mesh = Props.model("digital_chevrons")
	flash.scale = Vector3(.15, .22, 1)
	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color("fff4d4")
	flash.material_override = light
	camera.get_node("Lens").add_child(flash)
	flash.visible = false
	var board := instance("speed_display")
	board.name = "SpeedDisplay"
	board.transform = road_pose(road, display_distance)
	var edge: float = (
		road.half_width(display_distance)
		+ maxf(road.rail_setback(display_distance, 1), road.rail_setback(display_distance, -1))
	)
	board.scale.x = maxf(1, (edge + 1.4) / 10.0)
	add_child(board)
	var screen: Marker3D = board.get_node("Screen")
	var panel := MeshInstance3D.new()
	panel.mesh = Props.model("digital_chevrons")
	panel.scale = Vector3(18.2 / 3, 4.9 / 1.5, 1)
	var led := ShaderMaterial.new()
	led.shader = preload("res://shaders/digital_chevrons.gdshader")
	led.set_shader_parameter("show_arrows", false)
	led.set_shader_parameter("animate", false)
	led.set_shader_parameter("led_color", Color("29d6e8"))
	panel.material_override = led
	screen.add_child(panel)
	label(screen, "YOUR SPEED", Vector3(0, 1.7, .08), 52, .017, Color("9cdbdf"))
	number = label(screen, "---", Vector3(-1, -.1, .08), 160, .023, Color("ffe184"))
	label(screen, "km/h", Vector3(4.7, -.5, .08), 46, .023, Color("c6e7e5"))
	label(screen, "SPEED SNAPSHOT", Vector3(0, -1.85, .08), 34, .016, Color("8fbbcd"))


func label(parent: Node3D, text: String, at: Vector3, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var value := Label3D.new()
	value.font = FONT
	value.font_size = font_size
	value.pixel_size = pixel_size
	value.text = text
	value.position = at
	value.modulate = color
	value.outline_size = 4
	value.shaded = false
	parent.add_child(value)
	return value


func reset() -> void:
	previous_distance = -1
	previous_speed = 0
	previous_eligible = false
	captured_lap = -1
	pending_speed = -1
	displayed_speed = -1
	capture_count = 0
	reveal_left = 0
	flash_left = 0
	if number != null:
		number.text = "---"
	if flash != null:
		flash.visible = false


func advance(delta: float, distance: float, speed: float, lane: float, eligible: bool, lap: int = 0) -> void:
	flash_left = maxf(0, flash_left - delta)
	flash.visible = flash_left > 0
	if pending_speed >= 0:
		reveal_left -= delta
		if reveal_left <= 0:
			displayed_speed = pending_speed
			number.text = str(displayed_speed)
			pending_speed = -1
	var d: float = fposmod(distance, road.length) if road.closed_loop else distance
	var traveled := d - previous_distance
	var continuous := previous_distance >= 0 and traveled > 0 and traveled <= maxf(8, speed * delta * 1.8 + 5)
	var on_road: bool = absf(lane) <= road.half_width(d) - .5
	if (
		eligible
		and previous_eligible
		and on_road
		and continuous
		and captured_lap != lap
		and previous_distance < capture_distance
		and d >= capture_distance
	):
		var fraction := clampf((capture_distance - previous_distance) / traveled, 0, 1)
		pending_speed = maxi(0, roundi(lerpf(previous_speed, speed, fraction) * 3.6))
		captured_lap = lap
		capture_count += 1
		reveal_left = REVEAL_DELAY
		flash_left = .12
		flash.visible = true
	previous_distance = d
	previous_speed = speed
	previous_eligible = eligible and on_road
