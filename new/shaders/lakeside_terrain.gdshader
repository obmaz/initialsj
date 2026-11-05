shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D ground_grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float patches = noise(world_position.xz * 0.055);
	vec3 grass = texture(ground_grain, world_position.xz / 6.0).rgb * mix(0.80, 1.06, patches);
	float shore = 1.0 - smoothstep(0.15, 1.3, world_position.y);
	ALBEDO = mix(grass, vec3(0.16, 0.145, 0.11), shore * 0.65);
	ROUGHNESS = 1.0;
	SPECULAR = 0.10;
}
