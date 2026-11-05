shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
varying float seed;
void vertex() {
	seed = MODEL_MATRIX[3].x * 0.31 + MODEL_MATRIX[3].z * 0.17;
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	float angle = TIME * 2.4 + seed;
	vec2 p = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * (UV - 0.5);
	float shape = 1.0 - smoothstep(0.30, 0.46, length(p * vec2(1.0, 1.6)));
	ALBEDO = mix(vec3(1.0, 0.52, 0.68), vec3(1.0, 0.92, 0.96), UV.y);
	ALPHA = shape * COLOR.a;
}
