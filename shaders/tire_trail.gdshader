shader_type spatial;
render_mode blend_mix, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
varying float born;
varying float strength;
varying float metres;
void vertex() { born = INSTANCE_CUSTOM.r; strength=INSTANCE_CUSTOM.g; metres=INSTANCE_CUSTOM.b; }
void fragment() {
	float edge = smoothstep(0.0, 0.18, UV.x) * (1.0 - smoothstep(0.82, 1.0, UV.x));
	float age = 1.0 - smoothstep(18.0, 38.0, clock - born);
	float grooves = .78 + .22 * smoothstep(.15,.65,abs(sin(UV.x*36.0)));
	float grain = .88 + .12 * sin(UV.y * metres * 85.0 + sin(UV.x*31.0));
	ALBEDO = vec3(.009,.012,.016);
	ROUGHNESS=.96; SPECULAR=.08;
	ALPHA = edge * age * strength * grooves * grain * .76;
}
