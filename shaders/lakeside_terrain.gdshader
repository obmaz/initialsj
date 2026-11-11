shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
render_mode diffuse_burley;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
varying vec3 world_position;
varying float steepness;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	steepness = 1.0-abs((MODEL_NORMAL_MATRIX*NORMAL).y);
}
void fragment() {
	float patches = noise(world_position.xz * 0.055);
	vec3 grass = gv_surface(terrain_variants,world_position.xz,2.56,vec2(4,2),vec2(0))*mix(.9,1.03,patches);
	float shore = 1.0 - smoothstep(0.15, 1.3, world_position.y);
	vec3 rock = mix(vec3(0.17,0.20,0.22),vec3(0.36,0.38,0.36),noise(world_position.xy*0.18));
	vec3 terrain = mix(grass,rock,smoothstep(0.25,0.75,steepness));
	ALBEDO = mix(terrain,vec3(0.16,0.145,0.11),shore*0.65);
	ROUGHNESS = 1.0;
	SPECULAR = 0.10;
	float height=dot(ALBEDO,vec3(.2126,.7152,.0722));
	NORMAL=relief_normal(height,VERTEX,NORMAL,mix(.28,.65,steepness));
	AO=mix(.8,1.0,smoothstep(.05,.5,height));AO_LIGHT_AFFECT=.5;
}
