shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ground_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.3,0.45,0.3,1.0);
uniform bool grassy = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 grain = texture(ground_grain,world_position.xz/7.0).rgb;
	float strata = sin(world_position.y*1.2+sin(world_position.x*0.025)*2.0)*0.5+0.5;
	ALBEDO = grassy ? grain*vec3(0.8,0.93,0.72) : base_color.rgb*mix(0.78,1.05,strata);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
