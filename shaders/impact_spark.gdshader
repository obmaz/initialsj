shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	float angle = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453) * 6.283185;
	VERTEX.xy = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * VERTEX.xy;
	mat4 facing = mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0,0.7);
	float core = exp(-dot(p,p) * 30.0);
	ALBEDO = mix(vec3(1.0,0.28,0.02),vec3(1.0,0.94,0.5),core) * 1.6;
	ALPHA = core * COLOR.a;
}
