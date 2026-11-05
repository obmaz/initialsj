shader_type spatial;
render_mode blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	float sides = smoothstep(0.0, 0.22, UV.x) * (1.0 - smoothstep(0.78, 1.0, UV.x));
	float ends = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.83, 1.0, UV.y));
	float grain = texture(asphalt_texture, UV * vec2(1.0, 24.0)).r;
	ALBEDO = vec3(0.008, 0.009, 0.011);
	ROUGHNESS = 0.96;
	ALPHA = sides * ends * (0.26 + grain * 0.55);
}
