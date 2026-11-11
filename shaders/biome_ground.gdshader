shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
uniform vec4 ground_color : source_color = vec4(0.4,0.6,0.3,1);
uniform float grassness = 1.0;
uniform bool urban_paving = false;
uniform bool detailed_terrain = false;
uniform sampler2D region_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 detail;
	if (detailed_terrain) detail = gv_surface(region_variants,world.xz,3.8,vec2(2),vec2(0));
	else detail = gv_surface(terrain_variants,world.xz,2.56,vec2(4,2),grassness>.5 ? vec2(0) : vec2(2,0));
	float luma = dot(detail,vec3(0.3,0.59,0.11));
	ALBEDO = mix(ground_color.rgb*(.7+luma*.9),detail*vec3(.98,1,.93),grassness*.78);
	if (detailed_terrain) {
		ALBEDO = detail;
	}
	if (urban_paving) {
		vec2 paved_uv = world.xz*0.35;
		vec2 tile = abs(fract(paved_uv)-0.5);
		float footprint = max(fwidth(paved_uv.x),fwidth(paved_uv.y));
		float joint = smoothstep(0.465-footprint,0.49+footprint,max(tile.x,tile.y));
		joint *= 1.0-smoothstep(0.15,0.5,footprint);
		ALBEDO = ground_color.rgb*(0.82+luma*0.22)*(1.0-joint*0.18);
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
