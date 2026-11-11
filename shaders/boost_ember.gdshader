shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
varying vec4 particle_color;
uniform vec4 tint : source_color = vec4(.1,.7,1.,1.);
void vertex() {
	particle_color = COLOR;
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	vec2 p = (UV - .5) * 2.;
	float core = max(0., 1. - dot(p,p));
	ALBEDO = mix(tint.rgb, vec3(1), core * .18) * 1.1;
	ALPHA = core * core * particle_color.a;
}
