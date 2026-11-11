shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.1, 0.7, 1.0, 1.0);
uniform float strength = 1.0;
uniform bool calm = false;
void fragment() {
	float flicker = calm ? 1.0 : 0.9 + 0.1 * sin(TIME * 48.0 + UV.y * 18.0);
	float core = smoothstep(0.15, 0.9, UV.y);
	ALBEDO = mix(tint.rgb * .65, mix(tint.rgb, vec3(1.0), .28), core) * .8;
	float bands = .82 + .18 * sin(UV.y * 28.0 - (calm ? 0.0 : TIME * 35.0));
	ALPHA = (0.20 + core * 0.45) * bands * flicker * smoothstep(0.0, 0.25, UV.y) * strength;
}
