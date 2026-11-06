shader_type spatial;
render_mode cull_disabled;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
	vec3 tex = texture(dirt_texture,UV).rgb;
	float macro = texture(dirt_texture,UV*0.23).r;
	ALBEDO = tex*(0.72+macro*0.20);
	ROUGHNESS = 1.0;
	SPECULAR = 0.06;
}
