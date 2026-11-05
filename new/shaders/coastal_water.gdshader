shader_type spatial;
render_mode diffuse_burley;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; }
void fragment() {
	float wave = sin(world.x * 0.16 + TIME * 1.5) * cos(world.z * 0.21 - TIME * 1.1);
	ALBEDO = mix(vec3(0.025,0.26,0.44),vec3(0.08,0.51,0.65),wave * 0.5 + 0.5);
	NORMAL_MAP = vec3(0.5 + sin(world.x * 0.2 + TIME) * 0.09,0.5 + cos(world.z * 0.3 - TIME) * 0.09,1);
	ROUGHNESS = 0.21;
	SPECULAR = 0.8;
}
