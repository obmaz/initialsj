shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
varying float born;
void vertex() { born = INSTANCE_CUSTOM.r; }
void fragment() {
	float edge = smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	float age = 1.0 - smoothstep(3.0, 9.0, clock - born);
	ALBEDO = vec3(0.025, 0.03, 0.035);
	ALPHA = edge * age * 0.38;
}
