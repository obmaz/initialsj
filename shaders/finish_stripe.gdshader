shader_type spatial;
render_mode cull_disabled;
uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	float checker = mod(floor(UV.x)+floor(UV.y),2.0);
	vec3 grain = texture(asphalt_texture,UV*0.3).rgb;
	ALBEDO = mix(vec3(0.055),vec3(0.87),checker)*(0.82+grain*0.25);
	ROUGHNESS = 0.94;
	SPECULAR = 0.05;
}
