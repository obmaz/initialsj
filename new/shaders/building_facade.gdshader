shader_type spatial;
varying vec3 local_point;
varying vec3 local_normal;
varying vec4 dimensions;
void vertex() {
	local_point = VERTEX;
	local_normal = NORMAL;
	dimensions = INSTANCE_CUSTOM;
}
void fragment() {
	bool side = abs(local_normal.x) > 0.5;
	float u = side ? local_point.z * dimensions.z : local_point.x * dimensions.x;
	float v = local_point.y * dimensions.y;
	vec2 cell = fract(vec2(u / 3.2, v / 4.0));
	float pane = smoothstep(0.13,0.18,cell.x) * (1.0-smoothstep(0.77,0.82,cell.x));
	pane *= smoothstep(0.18,0.23,cell.y) * (1.0-smoothstep(0.70,0.75,cell.y));
	pane *= 1.0-step(0.5,abs(local_normal.y));
	float floor_line = 1.0-smoothstep(0.015,0.045,abs(cell.y-0.02));
	vec3 concrete = mix(vec3(0.28,0.33,0.36),vec3(0.53,0.48,0.40),dimensions.a);
	vec3 glass = mix(vec3(0.12,0.24,0.32),vec3(0.41,0.60,0.69),fract(floor(u/3.2)*0.37+floor(v/4.0)*0.21+dimensions.a));
	ALBEDO = mix(concrete * (1.0-floor_line*0.3),glass,pane);
	METALLIC = pane * 0.65;
	ROUGHNESS = mix(0.83,0.24,pane);
	EMISSION = glass * pane * 0.07;
}
