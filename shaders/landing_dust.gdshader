shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	ALBEDO = vec3(0.58,0.55,0.47);
	ALPHA = (1.0-smoothstep(0.10,0.5,length(UV-vec2(0.5))))*COLOR.a;
}
