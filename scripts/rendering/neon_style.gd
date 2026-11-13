extends RefCounted
# 기존 보조광과 코스 인스턴스 노면만 조정한다. 광원·재질 복제·그림자 패스는 추가하지 않는다.
const CIRCUITS := ["8adfff", "ffcf79", "9d9fff", "79efdc", "ffae9c"]
const REGIONS := {
	"hawaii": "79e3dc",
	"jungle": "a3dc93",
	"city": "a5cbff",
	"pyramid": "f4d390",
	"amusement": "efa0dc",
	"jeju": "9de4ce",
	"ruins": "ddd2ae",
	"seoul": "96c9f4",
	"fuji": "f0b7d6",
	"neon": "c3a1ff",
	"canyon": "efba9a",
	"harbor": "89cddc",
	"bamboo": "b1dfa8",
	"snow": "b6d9ff",
	"volcano": "f6a998"
}


static func accent(mode: String, course: int, region: String) -> Color:
	return Color(CIRCUITS[clampi(course, 0, 4)] if mode == "track" else REGIONS.get(region, "79e3dc"))


static func apply(race: Node3D) -> void:
	var color := accent(race.mode, race.selected_course, race.track.scenery.theme)
	race.rim_light.light_color = color
	apply_section(race.track.active)


static func apply_section(road: Node3D) -> void:
	var theme: String = preload("res://scripts/track/route_library.gd").theme(road.stage, road.route_node)
	var color := accent("track" if road.closed_loop else "tour", road.course_id, theme)
	for surface in [road.road_surface, road.entry_surface]:
		if surface == null:
			continue
		var material := surface.material_override as ShaderMaterial
		if material != null and material.shader == preload("res://shaders/asphalt.gdshader"):
			material.set_shader_parameter("stylized_rim_tint", Vector3(color.r, color.g, color.b) * .045)
