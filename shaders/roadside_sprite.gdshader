shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec4 region;
void vertex() {
	region = INSTANCE_CUSTOM;
	vec3 toward = CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz;
	toward.y = 0.0;
	toward = normalize(toward);
	vec3 across = normalize(cross(vec3(0,1,0),toward));
	mat4 facing = mat4(vec4(across*length(MODEL_MATRIX[0].xyz),0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(toward,0),MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX*facing;
}
void fragment() {
	vec4 art = texture(atlas,region.xy+clamp(UV,vec2(0.001),vec2(0.999))*region.zw);
	ALBEDO = art.rgb;
	ALPHA = art.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}
