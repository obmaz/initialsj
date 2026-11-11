extends RefCounted
# 위경도 원경은 월드 방위에 고정한다. 랩 거리·카메라 회전에 따라 이미지 자체를 돌리지 않는다.


static func create(path: String) -> Sky:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/track_panorama.gdshader")
	material.set_shader_parameter("panorama", preload("res://scripts/rendering/render_resources.gd").fetch(path))
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	return sky
