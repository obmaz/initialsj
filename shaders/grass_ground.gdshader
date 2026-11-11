shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D terrain_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
uniform vec3 lawn_gain = vec3(1.);
uniform float mowing_strength = 0.;
varying vec2 ground_world;
void vertex(){ground_world=(MODEL_MATRIX*vec4(VERTEX,1)).xz;}
void fragment(){
	ALBEDO=gv_surface(terrain_variants,ground_world,2.56,vec2(4,2),vec2(0))*lawn_gain;
	if(mowing_strength>0.) {
		float stripe=smoothstep(-.4,.4,sin(dot(ground_world,vec2(.91,.41))*.261799));
		ALBEDO*=1.+mowing_strength*(stripe-.5);
	}
	ROUGHNESS=.98;SPECULAR=.08;
}
