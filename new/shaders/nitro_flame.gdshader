shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float flicker = 0.85 + 0.15 * sin(TIME * 48.0 + UV.y * 18.0);
	float core = smoothstep(0.15, 0.9, UV.y);
	ALBEDO = mix(vec3(0.04, 0.24, 1.0), vec3(0.55, 0.95, 1.0), core) * 1.5;
	float bands = 0.72 + 0.28 * sin(TIME * 35.0 + UV.y * 28.0);
	ALPHA = (0.20 + core * 0.45) * bands * flicker * smoothstep(0.0, 0.25, UV.y);
}
