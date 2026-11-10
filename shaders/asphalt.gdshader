shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
uniform float rain_wetness = 0.0;
varying vec3 world_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 aggregate = gv_surface(asphalt_variants,world_position.xz,2.56,vec2(2),vec2(0));
	float patches = noise(world_position.xz * 0.18);
	ALBEDO = aggregate * vec3(0.87, 0.91, 1.10) * mix(0.88, 1.12, patches);
	ROUGHNESS = 0.82 + patches * 0.12;
	SPECULAR = 0.28;
	ALBEDO *= mix(1.0,.62,rain_wetness);
	ROUGHNESS = mix(ROUGHNESS,.24,rain_wetness);
	SPECULAR = mix(SPECULAR,.65,rain_wetness);
	METALLIC = 0.0;
	float h = dot(texture(asphalt_texture,UV).rgb, vec3(0.333));
	float hx = dot(texture(asphalt_texture, UV + vec2(0.001, 0)).rgb, vec3(0.333));
	float hy = dot(texture(asphalt_texture, UV + vec2(0, 0.001)).rgb, vec3(0.333));
	NORMAL_MAP = normalize(vec3((h - hx) * 0.65, (h - hy) * 0.65, 1.0)) * 0.5 + 0.5;
}
