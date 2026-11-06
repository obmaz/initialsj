shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
uniform vec4 tint : source_color = vec4(0.1, 0.7, 1.0, 1.0);
void fragment() {
	float radius = length(UV - 0.5) * 2.0;
	float core = exp(-radius * 8.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), core) * 2.0;
	ALPHA = pow(max(0.0, 1.0 - radius), 2.0) * 0.75;
}
