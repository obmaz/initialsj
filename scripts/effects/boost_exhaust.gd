extends Node3D
# 배기구에 붙어 있는 GLB 화염·빔. 월드에 잔류하는 발사체나 방출기를 만들지 않는다.
const HEAT_SECONDS := 3.2
var held := 0.0
var heat := 0.0
var envelope := 0.0
var clock := 0.0
var tint := Color.WHITE
var flames: Array[MeshInstance3D] = []
var glows: Array[MeshInstance3D] = []
var rests: Array[Transform3D] = []
var accent := Color("56dfff")
var style := "hatch"
var shot_peak := 0.0
var previous_active := false
var previous_shot := false


func configure(car: Node3D) -> void:
	style = car.model
	accent = car.nitro_tint
	flames.assign(car.nitro_flames)
	glows.assign(car.nitro_glows)
	for flame in flames:
		rests.append(flame.transform)
		flame.material_override.set_shader_parameter("beam", style == "gt")
	reset()


func reset() -> void:
	held = 0
	heat = 0
	envelope = 0
	clock = 0
	shot_peak = 0
	previous_active = false
	previous_shot = false
	for i in range(flames.size()):
		flames[i].transform = rests[i]
		flames[i].visible = false
	for glow in glows:
		glow.visible = false


func advance(active: bool, delta: float, reduced: bool, _quality: int, shot: bool = false) -> void:
	if delta <= 0:
		return
	clock += delta
	var fired := active and ((shot and not previous_shot) or (style == "wedge" and not previous_active))
	shot_peak = 1.0 if fired else maxf(0, shot_peak - delta / .65)
	previous_active = active
	previous_shot = shot
	held = minf(HEAT_SECONDS, held + delta) if active else 0.0
	heat = lerpf(heat, held / HEAT_SECONDS, 1 - exp(-delta * (5 if active else 9)))
	envelope = move_toward(envelope, 1.0 if active else 0.0, delta * (16 if fired else 10))
	var length_scale := 1.0 + heat * 1.25
	var width := 1.0 + heat * .5
	match style:
		"gt":
			tint = Color("a8ffe9").lerp(Color("9f98ff"), heat)
			length_scale = 3.2 + heat * 2.6
			width = .26 + heat * .12
		"wedge":
			tint = Color("ff511a").lerp(Color("ffb54b"), shot_peak)
			length_scale = 1.6 + shot_peak * 3.6
			width = 1.25 + shot_peak * 2.2
		"muscle":
			tint = Color("ff6325").lerp(Color("ffc265"), maxf(heat, shot_peak))
			length_scale = 1.2 + heat + shot_peak * 2.7
			width = 1.25 + heat * .5 + shot_peak * 1.4
		_:
			tint = accent.lerp(Color("9b7cff"), heat).lerp(Color("fff0c0"), heat * heat * .5)
	var pulse := 1.0 if reduced or style == "gt" else 1.0 + sin(clock * 39) * .055
	for i in range(flames.size()):
		var flame := flames[i]
		flame.visible = envelope > .01
		flame.scale = Vector3(width, length_scale * pulse * maxf(.01, envelope), width)
		# 원뿔의 입구를 고정해 크기 변화가 배기구 접점을 이동시키지 않게 한다.
		flame.position = rests[i].origin + rests[i].basis.y * (.6 * (flame.scale.y - 1))
		flame.material_override.set_shader_parameter("tint", tint)
		flame.material_override.set_shader_parameter("strength", envelope)
		flame.material_override.set_shader_parameter("calm", reduced)
	for glow in glows:
		glow.visible = envelope > .01
		glow.scale = Vector3.ONE * (1 + heat * .4 + shot_peak * 1.2) * maxf(.01, envelope)
		glow.material_override.set_shader_parameter("tint", tint)
		glow.material_override.set_shader_parameter("strength", envelope)
