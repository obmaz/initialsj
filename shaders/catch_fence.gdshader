shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
varying float camera_distance;
void vertex() { camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz); }
void fragment() {
	vec2 uv = UV*vec2(7.0,24.0);
	vec2 grid = abs(fract(uv)-0.5);
	float edge = min(grid.x,grid.y);
	float aa = max(fwidth(uv.x),fwidth(uv.y))*0.75;
	float line = 1.0-smoothstep(0.035-aa,0.035+aa,edge);
	ALBEDO = vec3(0.39,0.49,0.53);
	ROUGHNESS = 0.7;
	ALPHA = line*0.72*(1.0-smoothstep(45.0,150.0,camera_distance));
}
