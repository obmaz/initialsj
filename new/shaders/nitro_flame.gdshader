shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float flicker = 0.85 + 0.15 * sin(TIME * 48.0 + UV.y * 18.0);
	float core = smoothstep(0.15, 0.9, UV.y);
	ALBEDO = mix(vec3(0.30, 0.12, 1.0), vec3(0.35, 0.9, 1.0), core) * 1.8;
	ALPHA = (0.38 + core * 0.45) * flicker;
}
