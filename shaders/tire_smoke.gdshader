shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void vertex() {
	// Face the camera while retaining each CPU particle's own scale and position.
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	vec2 p = UV - vec2(0.5);
	float detail = noise(UV * 5.0) * 0.65 + noise(UV * 13.0) * 0.35;
	float soft = 1.0 - smoothstep(0.05, 0.49, length(p) + (detail - 0.5) * 0.12);
	ALBEDO = mix(vec3(0.75, 0.80, 0.86), vec3(0.96, 0.97, 1.0), detail);
	ALPHA = COLOR.a * soft * 0.65;
}
