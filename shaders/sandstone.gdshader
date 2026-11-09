shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float layers = sin(world_position.y*0.83+sin(world_position.x*0.016)*1.7+sin(world_position.z*0.021));
	float seam = smoothstep(0.75,0.94,layers);
	float grain = fract(sin(dot(floor(world_position.xz*2.0),vec2(12.9898,78.233)))*43758.5453);
	ALBEDO = mix(vec3(0.44,0.17,0.09),vec3(0.80,0.47,0.25),layers*0.25+0.60)*(1.0-seam*0.18)*(0.92+grain*0.12);
	ROUGHNESS = 1.0;
	SPECULAR = 0.04;
}
