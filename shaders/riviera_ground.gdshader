shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ground_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.3,0.45,0.3,1.0);
uniform bool grassy = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float strata = sin(world_position.y*1.2+sin(world_position.x*0.025)*2.0)*0.5+0.5;
	if(grassy) ALBEDO=gv_surface(terrain_variants,world_position.xz,2.56,vec2(4,2),vec2(0))*vec3(.96,1.0,.92);
	else ALBEDO=base_color.rgb*mix(.78,1.05,strata)*(gv_surface(terrain_variants,world_position.xz,3.6,vec2(4,2),vec2(2,0))*.65+vec3(.65));
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
