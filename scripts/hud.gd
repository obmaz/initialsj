extends Control

const DESIGN := Vector2(1280, 720)
const INK := Color("11121bc9")
const CYAN := Color("19dcff")
const BLUE := Color("087aff")
const WHITE := Color("f6f7fa")
const GOLD := Color("ffda22")
const FONT = preload("res://assets/fonts/Roboto-BoldItalic.ttf")
const CAPTION_FONT = preload("res://assets/fonts/LiberationSans-BoldItalic.ttf")
const POSITION_FONT = preload("res://assets/fonts/PositionNumeral.tres")
const NUMBER_FONT = preload("res://assets/fonts/Roboto-BlackItalic.ttf")
const Library = preload("res://scripts/route_library.gd")
const Catalog = preload("res://scripts/vehicle_catalog.gd")
const PAUSE_BUTTON := Rect2(814,15,66,60)
const HOME_TOUR := Rect2(100,470,520,170)
const HOME_TRACK := Rect2(660,470,520,170)
const HOME_SETTINGS := Rect2(1000,24,250,84)
const COURSE_FUJI := Rect2(100,150,520,440)
const COURSE_SEOCHO := Rect2(660,150,520,440)
const FUJI_PHOTO = preload("res://assets/environment/fuji-lake-panorama.png")
const SEOCHO_PHOTO = preload("res://assets/environment/seocho/skyline-panorama.png")
const GARAGE_BACK := Rect2(60,24,220,84)
const SETTINGS_SOUND := Rect2(365,180,550,78)
const SETTINGS_MOTION := Rect2(365,266,550,78)
const SETTINGS_GRAPHICS := Rect2(365,352,550,78)
const SETTINGS_INSTALL := Rect2(365,438,550,78)
const SETTINGS_CLOSE := Rect2(365,542,550,82)
const SPLASH = preload("res://assets/ui/coast-rush-splash.png")
const GARAGE_START := Rect2(930,630,290,76)
const GARAGE_MOTION := Rect2(205,604,160,40)
const GARAGE_SOUND := Rect2(380,604,170,40)
const MAIN_MENU_BUTTON := Rect2(390,578,500,78)
const START_BUTTON := Rect2(390, 483, 500, 82)
const MOTION_BUTTON := Rect2(307, 424, 300, 46)
const SOUND_BUTTON := Rect2(630, 424, 330, 46)
var race: Node3D
var fingers: Dictionary = {}
var font: Font = FONT
var bottle_texture: Texture2D
var drift_texture: Texture2D
var coin_texture: Texture2D
var install_note := ""
var previous_vehicle := 0
var selection_blend := 1.0
var shown_abilities := PackedFloat32Array()
var rpm_ring: MeshInstance2D
var rpm_material: ShaderMaterial
var dial_cache: SubViewport
var dial_backdrop: GradientTexture2D
var minimap_route := Curve2D.new()
var minimap_points := PackedVector2Array()
var coin_balance := 0
var drift_combo := 0.0
var drift_fade := 0.0
var last_score := 0.0
var was_drifting := false
# The time panel doubles as the touch pause control.
var buttons := {
	"left": Rect2(27, 562, 108, 108),
	"right": Rect2(159, 562, 108, 108),
	"drift": Rect2(1051, 445, 98, 98),
	"cell": Rect2(947,445,88,88),
	"nitro": Rect2(1166,443,100,100),
	"gas": Rect2(1090, 557, 120, 120),
	"brake": Rect2(955, 562, 110, 110),
	"pause": Rect2(894,15,378,60),
}

func _ready() -> void:
	build_dial_backdrop()
	if DisplayServer.get_name() != "headless":
		dial_cache = SubViewport.new()
		dial_cache.size = Vector2i(600,600)
		dial_cache.disable_3d = true
		dial_cache.transparent_bg = true
		dial_cache.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(dial_cache)
		var face := preload("res://scripts/gauge_face.gd").new()
		face.backdrop = dial_backdrop
		face.scale = Vector2(2,2)
		dial_cache.add_child(face)
		build_rpm_ring()
	bottle_texture = load_icon("res://assets/ui/nitro-bottle.png")
	drift_texture = load_icon("res://assets/ui/drift-car.png")
	coin_texture = load_icon("res://assets/ui/coin.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build_rpm_ring() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	for segment in range(38):
		var tint := GOLD if segment >= 28 else CYAN
		if segment >= 33: tint = Color("ff4f69")
		var a := lerpf(deg_to_rad(165),deg_to_rad(354),segment/38.0)
		var b := lerpf(deg_to_rad(165),deg_to_rad(354),(segment+0.72)/38.0)
		for part in range(3):
			var first := lerpf(a,b,part/3.0)
			var last := lerpf(a,b,(part+1)/3.0)
			var points := [Vector2.from_angle(first)*115.5,Vector2.from_angle(first)*121.5,Vector2.from_angle(last)*115.5,Vector2.from_angle(last)*121.5]
			for i in [0,1,2,1,3,2]:
				vertices.append(Vector3(points[i].x,points[i].y,0))
				colors.append(tint)
				uv.append(Vector2((segment+0.5)/38.0,0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	rpm_ring = MeshInstance2D.new()
	rpm_ring.mesh = mesh
	rpm_material = ShaderMaterial.new()
	rpm_material.shader = preload("res://shaders/rpm_ring.gdshader")
	rpm_ring.material = rpm_material
	rpm_ring.visible = false
	add_child(rpm_ring)

func vehicle_changed(old_index: int) -> void:
	previous_vehicle = old_index
	selection_blend = 0.0 if not race.motion_reduced else 1.0
	if race.screen_transition != null and race.sound_enabled: race.screen_transition.ui_sound.play()

func load_icon(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var source: Texture2D = load(path)
	var texture := AtlasTexture.new()
	texture.atlas = source
	# Ignore almost invisible glow/noise when fitting generated art into a small HUD target.
	var image := source.get_image()
	var first := Vector2i(image.get_width(), image.get_height())
	var last := Vector2i.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	texture.region = Rect2i(first, last - first + Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return texture

func draw_icon(texture: Texture2D, center: Vector2, bounds: Vector2, rotation: float = 0) -> bool:
	if texture == null:
		return false
	var size_px := texture.get_size()
	size_px *= minf(bounds.x / size_px.x, bounds.y / size_px.y)
	if rotation != 0:
		draw_set_transform(ui_offset() + center * ui_scale(), rotation, Vector2.ONE * ui_scale())
		draw_texture_rect(texture, Rect2(-size_px / 2, size_px), false)
		draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	else:
		draw_texture_rect(texture, Rect2(center - size_px / 2, size_px), false)
	return true

func ui_scale() -> float:
	var viewport := get_viewport_rect().size
	return minf(viewport.x / DESIGN.x, viewport.y / DESIGN.y)

func ui_offset() -> Vector2:
	return (get_viewport_rect().size - DESIGN * ui_scale()) / 2.0

func to_design(pos: Vector2) -> Vector2:
	return (pos - ui_offset()) / ui_scale()

func hit_button(action: String, pos: Vector2) -> bool:
	if action == "cell" and race.vehicle.mode != "hybrid": return false
	if not buttons.has(action):
		return false
	var rect: Rect2 = buttons[action]
	if action == "pause":
		return rect.has_point(pos) or PAUSE_BUTTON.has_point(pos)
	return pos.distance_to(rect.get_center()) <= rect.size.x / 2.0

func handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var index: int = event.index if event is InputEventScreenTouch else -1
	if not event.pressed:
		fingers.erase(index)
		return
	var p := to_design(event.position)
	if race.state == "menu":
		if HOME_TOUR.has_point(p): race.navigate(func(): race.choose_mode("tour"))
		elif HOME_TRACK.has_point(p): race.navigate(race.open_courses)
		elif HOME_SETTINGS.has_point(p): race.navigate(race.open_settings)
		return
	if race.state == "courses":
		if COURSE_FUJI.has_point(p): race.navigate(func(): race.choose_mode("track",0))
		elif COURSE_SEOCHO.has_point(p): race.navigate(func(): race.choose_mode("track",1))
		elif GARAGE_BACK.has_point(p): race.navigate(race.open_menu)
		return
	if race.state == "settings":
		if SETTINGS_SOUND.has_point(p): race.sound_enabled = not race.sound_enabled
		elif SETTINGS_MOTION.has_point(p): race.motion_reduced = not race.motion_reduced
		elif SETTINGS_GRAPHICS.has_point(p): race.cycle_graphics()
		elif SETTINGS_INSTALL.has_point(p):
			if OS.has_feature("web"): JavaScriptBridge.eval("window.initialsjInstallGame()")
			else: install_note = "OPEN THE WEB VERSION TO INSTALL"
		elif SETTINGS_CLOSE.has_point(p): race.navigate(race.close_settings)
		return
	if race.state == "ready":
		if GARAGE_BACK.has_point(p):
			if race.mode == "track": race.navigate(race.open_courses)
			else: race.navigate(race.open_menu)
		elif GARAGE_START.has_point(p): race.start_race()
		else:
			for i in range(3):
				if garage_card(i).has_point(p): race.select_vehicle(i)
		return
	if race.state in ["paused","finished","failed"]:
		if SOUND_BUTTON.has_point(p): race.sound_enabled = not race.sound_enabled
		elif MOTION_BUTTON.has_point(p): race.motion_reduced = not race.motion_reduced
		elif race.state == "paused" and MAIN_MENU_BUTTON.has_point(p): race.navigate(race.open_menu)
		elif START_BUTTON.has_point(p) or (race.state == "paused" and hit_button("pause",p)):
			if race.state == "paused": race.resume_tour()
			else: race.navigate(race.open_garage)
		return
	if hit_button("pause",p) and race.state in ["racing","countdown"]:
		race.pause_tour()
	else: move_pointer(index,event.position)

func move_pointer(index: int, pos: Vector2) -> void:
	if race.state not in ["racing","countdown"]: return
	fingers[index] = to_design(pos)

func held(action: String) -> bool:
	for pos in fingers.values():
		if hit_button(action, pos):
			return true
	return false

func touch_axis() -> float:
	return float(held("right")) - float(held("left"))

func _process(delta: float) -> void:
	if race == null:
		return
	selection_blend = minf(1,selection_blend+delta*5)
	var target: Dictionary = Catalog.abilities(race.selected_vehicle)
	if shown_abilities.size() != 4:
		for key in Catalog.ABILITY_KEYS: shown_abilities.append(target[key])
	for i in range(4): shown_abilities[i] = lerpf(shown_abilities[i],target[Catalog.ABILITY_KEYS[i]],1.0 if race.motion_reduced else 1-exp(-delta*12))
	if race.state in ["ready", "countdown"] or race.score < last_score:
		drift_combo = 0
		drift_fade = 0
		was_drifting = false
	if race.state == "racing":
		if race.drifting:
			if not was_drifting:
				drift_combo = 0
			drift_combo += maxf(0, race.score - last_score)
			drift_fade = 1.5
		else:
			drift_fade = maxf(0, drift_fade - delta)
		was_drifting = race.drifting
	last_score = race.score
	if rpm_ring != null:
		rpm_ring.position = ui_offset()+Vector2(137,413)*ui_scale()
		rpm_ring.scale = Vector2.ONE*ui_scale()*0.82
		rpm_ring.visible = race.state not in ["menu","courses","ready","settings"]
		rpm_ring.self_modulate.a = 0.4 if race.state == "paused" else 1.0
		rpm_material.set_shader_parameter("rpm_ratio",clampf(race.engine_rpm()/7500,0,1))
	queue_redraw()

func text_at(pos: Vector2, value: String, size_px: int, color: Color = WHITE, shadow: bool = true, face: Font = FONT) -> void:
	if shadow:
		draw_string_outline(face, pos + Vector2(0.5, 1.5), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 2, Color(0.02, 0.02, 0.04, color.a * 0.38))
	draw_string(face, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(pos: Vector2, value: String, size_px: int, color: Color = WHITE, face: Font = FONT) -> void:
	text_at(pos - Vector2(face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2, 0), value, size_px, color, true, face)

func slant(rect: Rect2, color: Color = INK, cut: float = 16, fade: bool = false) -> PackedVector2Array:
	var p := PackedVector2Array([rect.position + Vector2(cut, 0), rect.position + Vector2(rect.size.x, 0), rect.end - Vector2(cut, 0), rect.position + Vector2(0, rect.size.y)])
	if fade:
		# Hold the dark/blue colour under the lettering, then feather the trailing edge.
		var top := p[0].lerp(p[1], 0.52)
		var bottom := p[3].lerp(p[2], 0.52)
		draw_colored_polygon(PackedVector2Array([p[0], top, bottom, p[3]]), color)
		draw_polygon(PackedVector2Array([top, p[1], p[2], bottom]), PackedColorArray([color, Color(color, 0), Color(color, 0), color]))
	else:
		draw_colored_polygon(p, color)
	return p

func glow_line(points: PackedVector2Array, color: Color = CYAN, width: float = 2) -> void:
	for layer in [Vector2(18, 0.025), Vector2(11, 0.05), Vector2(5, 0.10), Vector2(2, 0.16)]:
		draw_polyline(points, Color(color, color.a * layer.y), width + layer.x, true)
	draw_polyline(points, color, width, true)

func rounded_polygon(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size()):
		var corner := points[i]
		var previous := points[(i - 1 + points.size()) % points.size()]
		var next := points[(i + 1) % points.size()]
		var enter := corner + (previous - corner).normalized() * radius
		var leave := corner + (next - corner).normalized() * radius
		for j in range(5):
			var t := j / 4.0
			result.append(enter.lerp(corner, t).lerp(corner.lerp(leave, t), t))
	return result

func build_dial_backdrop() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("101017a6"))
	gradient.set_color(1, Color("10101700"))
	gradient.add_point(0.65, Color("1010178c"))
	gradient.add_point(0.87, Color("10101744"))
	dial_backdrop = GradientTexture2D.new()
	dial_backdrop.width = 256
	dial_backdrop.height = 256
	dial_backdrop.gradient = gradient
	dial_backdrop.fill = GradientTexture2D.FILL_RADIAL
	dial_backdrop.fill_from = Vector2(0.5, 0.5)
	dial_backdrop.fill_to = Vector2(1, 0.5)

func arc_points(center: Vector2, radius: float, start: float, end: float, steps: int = 80) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(center + Vector2.from_angle(lerpf(start, end, float(i) / steps)) * radius)
	return points

func time_label(seconds: float) -> String:
	return "%02d:%06.3f" % [int(seconds) / 60, fmod(seconds, 60)]

func standings() -> Array[Dictionary]:
	return []

func _draw() -> void:
	if race == null:
		return
	draw_set_transform(ui_offset(), 0, Vector2.ONE * ui_scale())
	if race.state == "courses":
		draw_courses()
		return
	if race.state in ["menu","settings"]:
		draw_home()
		if race.state == "settings": draw_settings()
		return
	if race.state == "ready":
		draw_garage()
		return
	draw_competitor_markers()
	draw_pace_feedback()
	var rows := standings()
	draw_position(rows)
	draw_lap_time()
	draw_minimap(rows)
	draw_drift_score()
	draw_controls()
	draw_speedometer()
	draw_nitro()
	draw_menu()

func draw_position(_rows: Array[Dictionary]) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(25,14),Vector2(226,14),Vector2(200,78),Vector2(8,78)]),Color("17171cdd"))
	slant(Rect2(23,18,72,29),Color("090a10b3"),7)
	text_at(Vector2(32,40),"POS" if race.mode == "track" else "STG",24)
	var transform := Transform2D(Vector2(ui_scale(),0),Vector2(0,ui_scale()),ui_offset())
	draw_set_transform_matrix(transform*Transform2D(Vector2(1,0),Vector2(-0.18,1),Vector2(94,70)))
	text_at(Vector2.ZERO,str(race.race_position() if race.mode == "track" else race.stage_index+1),72,GOLD,true,POSITION_FONT)
	draw_set_transform(ui_offset(),0,Vector2.ONE*ui_scale())
	text_at(Vector2(151,67),"/8" if race.mode == "track" else "/5",40,WHITE,true,NUMBER_FONT)
	var title: String = race.course_title if race.mode == "track" else Library.title(race.stage_index,race.route_node)
	slant(Rect2(13,89,190,25),Color("073d59c9"),6,true)
	text_at(Vector2(24,107),title,14,CYAN)
	slant(Rect2(13,123,190,42),Color("121520bd"),7,true)
	text_at(Vector2(24,137),"SCORE",10,Color("99b8c9"))
	text_at(Vector2(24,158),comma_number(int(race.score)),23)
	text_at(Vector2(128,154),"PASS %d" % race.overtakes,11,Color("adc1cb"))

func comma_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var result := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += ","
		result += digits[i]
	return result

func draw_coin(center: Vector2) -> void:
	if draw_icon(coin_texture, center, Vector2(38, 38)):
		return
	draw_circle(center + Vector2(1, 2), 18, Color("4c310b99"))
	draw_circle(center, 17, Color("e8a421"))
	draw_circle(center - Vector2(1, 1), 14, Color("ffdb51"))
	draw_arc(center, 13, 0, TAU, 40, Color("ad751a"), 1, true)
	var star := PackedVector2Array()
	for i in range(10):
		star.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * (11.0 if i % 2 == 0 else 5.0))
	draw_colored_polygon(star, Color("fff49e"))
	draw_polyline(star + PackedVector2Array([star[0]]), Color("d19622"), 1, true)

func draw_lap_time() -> void:
	if race.state in ["racing","countdown","paused"]:
		slant(PAUSE_BUTTON,Color("15151ce6"),9)
		for x in [838,851]: draw_rect(Rect2(x,33,5,24),WHITE)
	if race.mode == "track":
		slant(Rect2(894,15,378,60),Color("15151ce6"),15)
		text_at(Vector2(914,43),"LAP",23)
		text_at(Vector2(975,61),"%d / 3" % mini(3,race.laps_completed+1),39,GOLD,true,NUMBER_FONT)
		text_at(Vector2(1090,35),"RACE TIME",12,Color("b9d1df"))
		text_at(Vector2(1085,62),time_label(race.elapsed),26)
		return
	slant(Rect2(894,15,378,60),Color("15151ce6"),15)
	text_at(Vector2(914,43),"TIME",23)
	var color := Color("ff785e") if race.time_left < 10 else GOLD
	text_at(Vector2(985,61),str(maxi(0,ceili(race.time_left))),48,color,true,NUMBER_FONT)
	draw_line(Vector2(1063,22),Vector2(1054,69),Color("e4e5e866"),1.2,true)
	text_at(Vector2(1080,35),"TOTAL TIME",13,Color("b9d1df"))
	text_at(Vector2(1080,62),time_label(race.elapsed),28)

func route_map_point(row: int, node: int) -> Vector2:
	return Vector2(1181 + (node-row*0.5)*33,190-row*24)

func draw_minimap(_rows: Array[Dictionary]) -> void:
	if race.mode == "track":
		draw_circuit_map()
		return
	slant(Rect2(1087,83,185,132),Color("121b2ac2"),10)
	var selected := 0
	for row in range(5):
		if row > 0 and row-1 < race.track.history.size(): selected += race.track.history[row-1]
		for node in range(row+1):
			var p := route_map_point(row,node)
			if row < 4:
				for side in [0,1]: draw_line(p,route_map_point(row+1,node+side),Color("728ea777"),1.2,true)
			var visited: bool = row <= race.stage_index and node == selected
			draw_circle(p,4.5 if visited else 3,CYAN if visited else Color("7cd5bc").lerp(Color("f1755c"),float(node)/maxi(1,row)))
			if visited and row > 0:
				var previous: int = selected-race.track.history[row-1]
				glow_line(PackedVector2Array([route_map_point(row-1,previous),p]),CYAN,1.8)
	var current := route_map_point(race.stage_index,race.route_node)
	draw_arc(current,7,0,TAU,24,GOLD,1.5,true)
	text_at(Vector2(1124,210),"START  /  GOAL",11,Color("b4d1df"))

func circuit_map_point(d: float) -> Vector2:
	var p: Vector3 = race.track.point(d)
	var bounds: Rect2 = race.track.map_bounds
	var scale_factor := minf(152/maxf(bounds.size.x,1),100/maxf(bounds.size.y,1))
	return Vector2(1180,143)+(Vector2(p.x,p.z)-bounds.get_center())*scale_factor

func draw_circuit_map() -> void:
	slant(Rect2(1087,83,185,132),Color("121b2ac2"),10)
	var points := PackedVector2Array()
	for i in range(101): points.append(circuit_map_point(race.track.length*i/100.0))
	draw_polyline(points,Color("d1e2ee"),3,true)
	for r in race.rivals:
		if r.active: draw_circle(circuit_map_point(r.distance),2.5,Color("ff9f68"))
	draw_circle(circuit_map_point(race.distance),5,CYAN)
	draw_rect(Rect2(circuit_map_point(80)-Vector2(3,3),Vector2(6,6)),WHITE)
	text_at(Vector2(1107,210),race.course_label,11,Color("b4d1df"))
	if race.selected_course == 1:
		var scenery: Node3D = race.track.scenery
		if scenery.active_landmark >= 0:
			text_at(Vector2(24,189),scenery.locations[scenery.active_landmark].name,11,CYAN)

func draw_drift_score() -> void:
	if drift_fade <= 0:
		return
	var alpha := minf(1, drift_fade * 2)
	slant(Rect2(1124, 263, 170, 70), Color(0.07, 0.07, 0.12, alpha * 0.14), 13, true)
	text_at(Vector2(1165, 289), "DRIFT", 27, Color(WHITE, alpha), true, CAPTION_FONT)
	text_at(Vector2(1143, 319), "+%d pts" % int(drift_combo), 30, Color(GOLD, alpha), true, NUMBER_FONT)
	glow_line(PackedVector2Array([Vector2(1138, 333), Vector2(1279, 323)]), Color(CYAN, alpha), 2)

func round_button(action: String, neon: bool = false) -> void:
	var rect: Rect2 = buttons[action]
	var c := rect.get_center()
	var radius := rect.size.x/2
	var active: bool = held(action) or (action == "gas" and race.throttling) or (action == "brake" and race.braking) or (action == "drift" and race.drifting) or (action == "nitro" and race.nitro_active)
	var accent := Color("ff7a66") if action == "brake" else (Color(race.vehicle.accent) if action in ["nitro","cell"] else CYAN)
	draw_circle(c,radius,Color("183447d9") if active else Color("122235a0"))
	draw_arc(c,radius-4,0,TAU,70,Color("ffffff14"),1,true)
	if neon:
		glow_line(arc_points(c,radius-1,0,TAU),Color(accent,1.0 if active else 0.75),2.4 if active else 1.4)
	else: draw_arc(c,radius-1,0,TAU,70,Color("e6f3ffb8"),1.6,true)

func pedal_icon(center: Vector2, gas: bool) -> void:
	var points := PackedVector2Array([center+Vector2(-13,-21),center+Vector2(11,-24),center+Vector2(18,13),center+Vector2(-17,13)])
	draw_colored_polygon(points,Color("dbf7ff") if gas else Color("ffd3c7"))
	for i in range(4): draw_line(center+Vector2(-9,-14+i*6),center+Vector2(9,-17+i*6),Color("254051"),2.5,true)

func draw_controls() -> void:
	for action in ["left","right"]:
		round_button(action)
		var c: Vector2 = buttons[action].get_center()
		var sign_x := -1.0 if action == "left" else 1.0
		var chevron := PackedVector2Array()
		for p in [Vector2(-13,-27),Vector2(5,-27),Vector2(32,0),Vector2(5,27),Vector2(-13,27),Vector2(13,0)]:
			chevron.append(c+Vector2((p.x-8)*sign_x,p.y))
		draw_colored_polygon(chevron,Color("ffffffe0"))
	round_button("drift")
	var c: Vector2 = buttons.drift.get_center()
	if race.drifting: draw_arc(c,49,0,TAU,64,CYAN,3,true)
	car_icon(c+Vector2(0,-12))
	centered(c+Vector2(0,35),"END DRIFT" if race.drifting else "DRIFT",14 if race.drifting else 19)
	var drift_hint := "TAP TO END" if race.drifting else ("STEER NOW" if race.drift_pending > 0 else ("STEER + TAP" if race.speed > 25 else "90 km/h+"))
	centered(c+Vector2(0,-60),drift_hint,12,CYAN if race.speed > 25 else Color("8ca0ac"))
	round_button("nitro",true)
	var nitro_center: Vector2 = buttons.nitro.get_center()
	bottle(nitro_center+Vector2(0,-10),0.43)
	centered(nitro_center+Vector2(0,35),"NITRO",18)
	draw_arc(nitro_center,52,-PI/2,-PI/2+TAU*race.nitro_ratio(),56,GOLD if race.nitro_active else CYAN,2,true)
	if race.vehicle.mode == "hybrid":
		round_button("cell",true)
		var cell: Vector2 = buttons.cell.get_center()
		centered(cell+Vector2(0,1),str(race.nitro_charges),30,Color(race.vehicle.accent))
		centered(cell+Vector2(0,28),"CELL / E",14)
	for action in ["brake","gas"]:
		round_button(action,true)
		c = buttons[action].get_center()
		pedal_icon(c+Vector2(0,-9),action == "gas")
		centered(c+Vector2(0,39),"GAS" if action == "gas" else "BRAKE",21)

func car_icon(center: Vector2) -> void:
	if draw_icon(drift_texture, center + Vector2(2, 4), Vector2(51, 51), 0.12):
		return
	var silhouette := PackedVector2Array([Vector2(-17, 12), Vector2(-17, -3), Vector2(-12, -13), Vector2(12, -13), Vector2(17, -3), Vector2(17, 12), Vector2(11, 12), Vector2(11, 7), Vector2(-11, 7), Vector2(-11, 12)])
	var points := PackedVector2Array()
	for p in silhouette:
		points.append(center + p.rotated(0.22))
	draw_colored_polygon(points, WHITE)
	var windscreen := PackedVector2Array()
	for p in [Vector2(-9, -9), Vector2(9, -9), Vector2(12, -2), Vector2(-12, -2)]:
		windscreen.append(center + p.rotated(0.22))
	draw_colored_polygon(windscreen, Color("30333b"))
	for side in [-1, 1]:
		var trail := PackedVector2Array()
		for i in range(12):
			trail.append(center + Vector2(side * 9 + sin(i * 0.6) * 4 - i * 0.55, 13 + i * 1.5))
		draw_polyline(trail, WHITE, 3.2, true)

func bottle(center: Vector2, scale_factor: float = 1) -> void:
	if draw_icon(bottle_texture, center, Vector2(64, 80) * scale_factor):
		return
	var shape := [Vector2(-12, 22), Vector2(12, 22), Vector2(14, 17), Vector2(14, -14), Vector2(6, -21), Vector2(6, -28), Vector2(-6, -28), Vector2(-6, -21), Vector2(-14, -14), Vector2(-14, 17)]
	var points := PackedVector2Array()
	for p in shape:
		points.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(points, Color("0aabeb"))
	glow_line(points + PackedVector2Array([points[0]]), CYAN, 2)
	var bolt := PackedVector2Array()
	for p in [Vector2(2, -14), Vector2(-9, 3), Vector2(-1, 3), Vector2(-4, 16), Vector2(10, -4), Vector2(2, -4)]:
		bolt.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(bolt, WHITE)
	var cap := PackedVector2Array()
	for p in [Vector2(-8, -32), Vector2(8, -32), Vector2(8, -27), Vector2(-8, -27)]:
		cap.append(center + p.rotated(0.55) * scale_factor)
	draw_colored_polygon(cap, WHITE)

func draw_speedometer() -> void:
	var ui := Transform2D(Vector2(ui_scale(),0),Vector2(0,ui_scale()),ui_offset())
	var gauge := Transform2D(Vector2(0.82,0),Vector2(0,0.82),Vector2(137,413)-Vector2(1150,626)*0.82)
	draw_set_transform_matrix(ui*gauge)
	var c := Vector2(1150, 626)
	var radius := 125.5
	var start := deg_to_rad(165)
	var end := deg_to_rad(354)
	if dial_cache != null:
		draw_texture_rect(dial_cache.get_texture(),Rect2(c-Vector2(150,150),Vector2(300,300)),false)
	var speed_kmh := int(race.speed * 3.6)
	centered(Vector2(1145, 630), str(speed_kmh), 64, WHITE, NUMBER_FONT)
	var gear := "N" if race.gear_number() == 0 else str(race.gear_number())
	centered(Vector2(1225, 663), gear, 38, WHITE, NUMBER_FONT)

	draw_set_transform(ui_offset(),0,Vector2.ONE*ui_scale())

func draw_nitro() -> void:
	var color := Color(race.vehicle.accent)
	bottle(Vector2(405,663),0.6)
	text_at(Vector2(443,651),"NITRO",24,color)
	text_at(Vector2(605,650),"TAP SHIFT" if race.vehicle.mode == "charges" else "HOLD SHIFT",16,Color("bad6e3"))
	if race.vehicle.mode == "hybrid":
		for i in range(2):
			draw_circle(Vector2(807+i*22,642),7,color if i < race.nitro_charges else Color("304252"))
	if race.boosting and not race.nitro_active and not race.pad_active: text_at(Vector2(443,624),"SLIPSTREAM",16,CYAN)
	var rim := rounded_polygon(PackedVector2Array([Vector2(442,661),Vector2(847,661),Vector2(835,691),Vector2(430,691)]),4)
	draw_colored_polygon(rim,Color("0b182bdf"))
	draw_polyline(rim+PackedVector2Array([rim[0]]),Color("8ab5cc99"),1.5,true)
	if race.vehicle.mode == "charges":
		for i in range(3):
			var rect := Rect2(445+i*129,667,120,17)
			draw_rect(rect,color if i < race.nitro_charges else Color("25374a"))
			if i == race.nitro_charges and race.nitro_burst_left > 0:
				rect.size.x *= race.nitro_burst_left/race.vehicle.burst_duration
				draw_rect(rect,GOLD)
	else:
		for i in range(9):
			var fill: float = clampf(race.nitro/100*9-i,0,1)
			if fill <= 0: break
			var x := 445.0+i*43
			draw_colored_polygon(PackedVector2Array([Vector2(x,667),Vector2(x+41*fill,667),Vector2(x+41*fill-8,684),Vector2(x-8,684)]),GOLD if race.nitro_active else color)

func garage_card(index: int) -> Rect2:
	return Rect2(80+index*380,530,360,84)

func draw_home() -> void:
	draw_rect(Rect2(-ui_offset()/ui_scale(),get_viewport_rect().size/ui_scale()),Color("07111e"))
	draw_texture_rect(SPLASH,Rect2(0,0,1280,720),false)
	draw_rect(Rect2(0,446,1280,274),Color("07111ee5"))
	for index in range(2):
		var rect: Rect2 = HOME_TOUR if index == 0 else HOME_TRACK
		var accent := CYAN if index == 0 else Color("ffae72")
		var x := rect.position.x
		slant(rect,Color("112334f5"),15)
		draw_line(rect.position+Vector2(15,0),rect.position+Vector2(rect.size.x,0),accent,3,true)
		text_at(Vector2(x+32,rect.position.y+65),"TOUR" if index == 0 else "TRACK",54,WHITE)
		text_at(Vector2(x+34,rect.position.y+108),"BRANCHING COAST RUN" if index == 0 else "CHOOSE YOUR CIRCUIT",24,accent)
		text_at(Vector2(x+34,rect.position.y+144),"5 STAGES / 16 ROUTES" if index == 0 else "2 COURSES / 3 LAPS",20,Color("a5becd"))
		text_at(Vector2(x+450,rect.position.y+85),">",48,accent)
	slant(HOME_SETTINGS,Color("102637ed"),10)
	centered(Vector2(HOME_SETTINGS.get_center().x,77),"SETTINGS",30)

func draw_courses() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("091522"))
	slant(GARAGE_BACK,Color("20374a"),7)
	centered(Vector2(170,78),"< BACK",28)
	text_at(Vector2(100,121),"SELECT CIRCUIT",35)
	for i in range(2):
		var rect: Rect2 = COURSE_FUJI if i == 0 else COURSE_SEOCHO
		var accent := CYAN if i == 0 else Color("ffbc72")
		slant(rect,Color("142738"),10)
		var texture: Texture2D = FUJI_PHOTO if i == 0 else SEOCHO_PHOTO
		var image_box := Rect2(rect.position+Vector2(12,12),Vector2(496,240))
		# Cover crop in the UI only; original location photographs stay intact.
		var source := Rect2(Vector2.ZERO,texture.get_size())
		var ratio := image_box.size.x/image_box.size.y
		if source.size.x/source.size.y > ratio:
			var width := source.size.y*ratio
			source.position.x = (source.size.x-width)*0.5
			source.size.x = width
		else:
			var height := source.size.x/ratio
			source.position.y = (source.size.y-height)*0.5
			source.size.y = height
		draw_texture_rect_region(texture,image_box,source)
		var x := rect.position.x+26
		text_at(Vector2(x,440),"01 / FUJI LAKESIDE" if i == 0 else "02 / SEOCHO CITY LOOP",26,accent)
		text_at(Vector2(x,471),"4.36 KM / RIDGE, HAIRPIN, TUNNEL" if i == 0 else "6.50 KM / REAL MAP PROTOTYPE",15,WHITE)
		text_at(Vector2(x,500),"LAKESIDE STRAIGHT > RIDGE > DOWNHILL" if i == 0 else "MAPLE 2 > KIPARANG > MIDO > GYODAE",12,Color("adc2d0"))
		text_at(Vector2(x,524),"3 LAPS / 8 CARS" if i == 0 else "LANDMARK RUN / 3 LAPS",12,Color("adc2d0"))
		draw_line(Vector2(x,545),Vector2(x+465,545),Color(accent,0.5),1)
		text_at(Vector2(x,574),"CHOOSE TRACK",24,accent)
	centered(Vector2(640,637),"SELECT A CIRCUIT, THEN CHOOSE YOUR CAR",14,Color("91aab9"))
	centered(Vector2(640,660),"Road geometry: OpenStreetMap contributors / ODbL",10,Color("688293"))
	centered(Vector2(920,678),"Generated landmarks / real street layout",10,Color("688293"))

func draw_settings() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("020812d9"))
	slant(Rect2(300,90,680,565),Color("101e2bfc"),20)
	text_at(Vector2(365,164),"SETTINGS",42)
	for rect in [SETTINGS_SOUND,SETTINGS_MOTION,SETTINGS_GRAPHICS,SETTINGS_INSTALL]: slant(rect,Color("20374a"),9)
	text_at(Vector2(393,225),"SOUND",28)
	text_at(Vector2(815,225),"ON" if race.sound_enabled else "OFF",30,CYAN)
	text_at(Vector2(393,316),"REDUCED MOTION",26)
	text_at(Vector2(815,316),"ON" if race.motion_reduced else "OFF",30,CYAN)
	text_at(Vector2(393,402),"GRAPHICS",28)
	text_at(Vector2(795,402),["AUTO","HIGH","FAST"][race.graphics_mode],28,CYAN)
	text_at(Vector2(393,488),"INSTALL GAME",30,WHITE)
	text_at(Vector2(854,488),"+",35,CYAN)
	if not install_note.is_empty(): centered(Vector2(640,536),install_note,17,Color("b2cbd8"))
	slant(SETTINGS_CLOSE,CYAN,10)
	centered(Vector2(640,596),"DONE",34,Color("0a1b2b"))

func draw_garage() -> void:
	var color := Color(race.vehicle.accent)
	draw_rect(Rect2(-ui_offset()/ui_scale(),get_viewport_rect().size/ui_scale()),Color("08121f"))
	draw_line(Vector2(60,120),Vector2(1220,120),Color("264152"),1,true)
	slant(GARAGE_BACK,Color("20374a"),10)
	centered(Vector2(GARAGE_BACK.get_center().x,78),"< BACK",28,WHITE)
	centered(Vector2(640,68),("TRACK" if race.mode == "track" else "TOUR")+" / GARAGE",22,Color("9db6c9"))
	text_at(Vector2(1105,68),"%d / 3" % (race.selected_vehicle+1),16,color)
	text_at(Vector2(120,168),race.vehicle.name,48)
	text_at(Vector2(123,195),race.vehicle["class"],21,color)
	if race.previews != null:
		var blend := smoothstep(0,1,selection_blend)
		if blend < 1:
			draw_texture_rect(race.previews.textures[previous_vehicle],Rect2(80-24*blend,210,690,300),false,Color(1,1,1,1-blend))
		draw_texture_rect(race.previews.textures[race.selected_vehicle],Rect2(80+28*(1-blend),210,690,300),false,Color(1,1,1,blend))
	text_at(Vector2(826,162),"PERFORMANCE",20,Color("9db6c9"))
	var abilities := Catalog.abilities(race.selected_vehicle)
	for i in range(4):
		var y := 203.0+i*58
		var rating: float = abilities[Catalog.ABILITY_KEYS[i]]
		text_at(Vector2(826,y),Catalog.ABILITY_LABELS[i],26,Color("c8d9e4"))
		text_at(Vector2(1115,y),"%.1f" % rating,26,color)
		draw_rect(Rect2(826,y+13,334,5),Color("263746"))
		draw_rect(Rect2(826,y+13,334*(shown_abilities[i] if shown_abilities.size() == 4 else rating)/10.0,5),color)
	text_at(Vector2(826,455),race.vehicle.nitro_title,24,color)
	text_at(Vector2(826,483),race.vehicle.nitro_help,19,Color("a1b8c9"))
	text_at(Vector2(80,511),["AGILE CORNERS. RECHARGE NITRO THROUGH DRIFTING.","HIGH TOP SPEED. TIME YOUR POWERFUL NITRO SHOTS.","QUICK LAUNCH. COMBINE NITRO AND OVERDRIVE CELLS."][race.selected_vehicle],22,Color("9db6c9"))
	for i in range(3):
		var rect := garage_card(i)
		var v := Catalog.spec(i)
		var selected: bool = i == race.selected_vehicle
		slant(rect,Color("203345") if selected else Color("101d2b"),8)
		if selected: draw_line(rect.position+Vector2(8,rect.size.y),rect.end,Color(v.accent),3,true)
		text_at(rect.position+Vector2(22,35),v.name,25,Color(v.accent) if selected else Color("bdcedb"))
		var role: String = ["AGILE / GAUGE","TOP SPEED / SHOTS","POWER / HYBRID"][i]
		text_at(rect.position+Vector2(23,66),role,18,Color("94acbe"))
	text_at(Vector2(80,678),"BEST "+(time_label(race.best_time) if race.best_time > 0 else "--:--.---"),22,GOLD)
	slant(GARAGE_START,color,8)
	centered(Vector2(GARAGE_START.get_center().x,680),"DRIVE",34,Color("07111e"))

func draw_menu() -> void:
	if race.state == "ready":
		draw_garage()
		return
	if race.state == "countdown":
		slant(Rect2(568, 248, 144, 136), Color("11121bba"), 24)
		var pulse := exp(-(ceili(race.countdown) - race.countdown) * 7.0)
		centered(Vector2(640, 353), str(maxi(1, ceili(race.countdown))), int(90 + 18 * pulse), GOLD)
	elif race.state in ["ready", "paused", "finished", "failed"]:
		draw_rect(Rect2(-ui_offset() / ui_scale(), get_viewport_rect().size / ui_scale()), Color("060b168f"))
		slant(Rect2(235, 100, 810, 575), Color("10121bf7"), 30)
		glow_line(PackedVector2Array([Vector2(265, 100), Vector2(1045, 100)]), CYAN, 2)
		text_at(Vector2(307,150),"INITIAL SJ / "+race.course_title if race.mode == "track" else "INITIAL SJ / GRAND TOUR",22,CYAN)
		text_at(Vector2(804, 150), "BEST " + (time_label(race.best_time) if race.best_time > 0 else "--:--.---"), 18, GOLD)
		var title := "GRAND TOUR" if race.state == "ready" else (("RACE PAUSED" if race.mode == "track" else "TOUR PAUSED") if race.state == "paused" else (("RACE FINISHED" if race.mode == "track" else "GOAL CLEAR!") if race.state == "finished" else "TIME OVER"))
		text_at(Vector2(307, 224), title, 62)
		if race.state == "finished":
			var detail := ("POS %d / 8" % race.race_position()) if race.mode == "track" else ("SCORE %d" % int(race.score))
			text_at(Vector2(307,288),detail,32,GOLD)
			text_at(Vector2(307,338),time_label(race.elapsed),42)
		elif race.state == "failed":
			text_at(Vector2(307,292),"SCORE %d" % int(race.score),32,GOLD)
		elif race.state == "paused":
			text_at(Vector2(307,294),race.vehicle.name,28,Color(race.vehicle.accent))
			text_at(Vector2(307,338),time_label(race.elapsed),35,Color("b9cedb"))
		for rect in [MOTION_BUTTON, SOUND_BUTTON]:
			slant(rect, Color("253548"), 8)
		var motion_label := "MOTION: LOW" if race.motion_reduced else "MOTION: FULL"
		var sound_label := "SOUND: ON" if race.sound_enabled else "SOUND: OFF"
		centered(Vector2(MOTION_BUTTON.get_center().x, 454), motion_label, 21, CYAN)
		centered(Vector2(SOUND_BUTTON.get_center().x, 454), sound_label, 21, CYAN)
		slant(START_BUTTON, CYAN, 13)
		var cta := "RESUME" if race.state == "paused" else ("CHOOSE CAR")
		centered(Vector2(640, 536), cta, 32, Color("0a1b2b"))
		if race.state == "paused":
			slant(MAIN_MENU_BUTTON,Color("253548"),8)
			centered(Vector2(640,627),"MAIN MENU",26,CYAN)

func draw_competitor_markers() -> void:
	if race.mode != "track" or race.state not in ["racing","countdown"]: return
	var nearby: Array[Dictionary] = []
	for rival in race.rivals:
		if not rival.active or not rival.car.visible: continue
		var gap: float = race.relative_gap(rival.distance,race.distance)
		if gap > 7 and gap < 100: nearby.append({"rival":rival,"gap":gap})
	nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.gap < b.gap)
	var occupied: Array[Rect2] = []
	for entry in nearby:
		var rival: Dictionary = entry.rival
		var world: Vector3 = rival.car.position+Vector3.UP*2.2
		if race.camera.is_position_behind(world): continue
		var point := to_design(race.camera.unproject_position(world))
		if point.x < 275 or point.x > 1020 or point.y < 175 or point.y > 450: continue
		var rect := Rect2(point-Vector2(24,25),Vector2(48,25))
		var overlaps := false
		for previous in occupied:
			if rect.grow(5).intersects(previous): overlaps = true
		if overlaps: continue
		occupied.append(rect)
		var place: int = race.competitor_position(rival.id)
		var suffix := "st" if place == 1 else ("nd" if place == 2 else ("rd" if place == 3 else "th"))
		slant(rect,Color("111724d9"),5)
		centered(Vector2(point.x,point.y-6),str(place)+suffix,18,GOLD if place == 1 else WHITE)
		if occupied.size() >= 3: break

func draw_pace_feedback() -> void:
	if race.state != "racing": return
	if race.launch_flash > 0: centered(Vector2(640,350),"GO!",76,Color(GOLD,minf(1,race.launch_flash*4)))
	if race.checkpoint_flash > 0:
		centered(Vector2(640,222),("LAP %d / 3" % mini(3,race.laps_completed+1)) if race.mode == "track" else ("CHECKPOINT +%ds" % int(race.checkpoint_award)),40,Color(GOLD,minf(1,race.checkpoint_flash*3)))
	elif race.mode == "tour" and race.stage_index < 4 and race.distance > race.track.length-260:
		var names := Library.next_titles(race.stage_index,race.route_node)
		centered(Vector2(640,225),"< " + names[0] + "   |   " + names[1] + " >",17,CYAN)
	var intensity: float = clampf((race.speed-38)/50,0,1)
	if not race.motion_reduced:
		var origin := Vector2(640,315)
		for i in range(34):
			var angle: float = TAU*fposmod(i*0.61803398875,1)
			var phase: float = fposmod(race.elapsed*(1.3+intensity*1.5)+i*0.317,1)
			var ray := Vector2.from_angle(angle)*Vector2(800,500)
			var start := origin+ray*(0.70+phase*0.6)
			var end := start+ray.normalized()*(22+phase*80)*intensity
			draw_line(start,end,Color(0.65,0.88,1,intensity*(0.26 if race.boosting else 0.16)*sin(phase*PI)),1.2,true)
	if race.impact > 0: draw_rect(Rect2(0,0,1280,720),Color(1,0.35,0.10,race.impact*0.07))
	if race.air.active and race.air.trick: centered(Vector2(640,568),"AIR TIME!",26,GOLD)
	elif race.air.landing_flash > 0.35 and race.air.trick: centered(Vector2(640,568),"LANDED / +100",21,Color("b7e9ff"))
	elif race.surface.pad_flash > 0: centered(Vector2(640,568),"BOOST PAD!",26,GOLD)
	elif race.surface.water_flash > 0: centered(Vector2(640,568),"WET ROAD / LOW GRIP",21,Color("a9dfff"))
	elif race.near_miss_flash > 0: centered(Vector2(640,568),"CLOSE PASS +150",23,GOLD)
	elif race.overtake_flash > 0: centered(Vector2(640,568),"PASS!",24,CYAN)
	elif race.boosting: centered(Vector2(640,568),("BOOST PAD!" if race.pad_active else ("OVERDRIVE!" if race.vehicle.mode == "hybrid" and race.nitro_burst_left > 0 else "NITRO!")) if race.nitro_active or race.pad_active else "SLIPSTREAM",23,CYAN)
	if race.corner_warning > 0.15:
		centered(Vector2(640,606),"BRAKE / CORNER %d km/h" % int(race.recommended_speed*3.6),19,Color(1,0.66,0.38,race.corner_warning))
