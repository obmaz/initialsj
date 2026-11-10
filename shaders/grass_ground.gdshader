shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
varying vec2 ground_world;
void vertex(){ground_world=(MODEL_MATRIX*vec4(VERTEX,1)).xz;}
void fragment(){
	ALBEDO=gv_surface(terrain_variants,ground_world,2.56,vec2(4,2),vec2(0));
	ROUGHNESS=.98;SPECULAR=.08;
}
