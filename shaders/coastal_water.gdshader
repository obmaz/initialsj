shader_type spatial;
render_mode diffuse_burley;
uniform vec4 deep_color : source_color = vec4(0.025,0.26,0.44,1);
uniform vec4 shallow_color : source_color = vec4(0.08,0.51,0.65,1);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; }
void fragment() {
	// Unequal, non-perpendicular swells avoid a regular checkerboard at speed.
	float a = world.x*0.047+world.z*0.031+TIME*0.7;
	float b = world.x*0.019-world.z*0.063-TIME*0.53;
	float c = world.x*0.113+world.z*0.072+TIME*1.1;
	float wave = sin(a)*0.5+sin(b)*0.32+sin(c)*0.18;
	vec3 normal_world = normalize(vec3(-cos(a)*0.025-cos(c)*0.012,1.0,-cos(b)*0.035-cos(c)*0.008));
	NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	float horizon = pow(1.0-max(dot(NORMAL,normalize(VIEW)),0.0),3.0);
	vec3 water = mix(deep_color.rgb,shallow_color.rgb,0.52+wave*0.14);
	ALBEDO = mix(water,vec3(0.38,0.59,0.66),horizon*0.48);
	ROUGHNESS = 0.34;
	SPECULAR = 0.55;
}
