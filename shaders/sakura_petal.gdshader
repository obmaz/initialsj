shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 petal_start : source_color = vec4(1,0.92,0.96,1);
uniform vec4 petal_end : source_color = vec4(1,0.52,0.68,1);
uniform float confetti = 0.0;
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
	vec3 color = mix(petal_end.rgb,petal_start.rgb,UV.y);
	vec3 carnival = 0.55 + 0.45*cos(seed+vec3(0,2.1,4.2));
	ALBEDO = mix(color,carnival,confetti);
	ALPHA = shape * COLOR.a;
}
