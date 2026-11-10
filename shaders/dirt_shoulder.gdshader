shader_type spatial;
render_mode cull_disabled;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
varying float steepness;
varying vec2 ground_world;
void vertex() { steepness = 1.0-abs((MODEL_NORMAL_MATRIX*NORMAL).y);ground_world=(MODEL_MATRIX*vec4(VERTEX,1)).xz; }
void fragment() {
	float macro = texture(dirt_texture,UV*0.23).r;
	if(COLOR.r<.5) ALBEDO=gv_surface(terrain_variants,ground_world,2.56,vec2(4,2),vec2(2,0))*(.72+macro*.20);
	else ALBEDO=mix(gv_surface(terrain_variants,ground_world,2.56,vec2(4,2),vec2(0))*.9,vec3(.23,.27,.25)*(.8+macro*.3),smoothstep(.27,.63,steepness));
	ROUGHNESS = 1.0;
	SPECULAR = 0.06;
}
