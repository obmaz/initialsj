shader_type spatial;
render_mode cull_disabled;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float steepness;
void vertex() { steepness = 1.0-abs((MODEL_NORMAL_MATRIX*NORMAL).y); }
void fragment() {
	vec3 tex = texture(dirt_texture,UV).rgb;
	float macro = texture(dirt_texture,UV*0.23).r;
	vec3 dirt = tex*(0.72+macro*0.20);
	vec3 grass = texture(grass_texture,UV).rgb*0.78;
	vec3 bank = mix(grass,vec3(0.23,0.27,0.25)*(0.8+macro*0.3),smoothstep(0.27,0.63,steepness));
	ALBEDO = mix(dirt,bank,COLOR.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.06;
}
