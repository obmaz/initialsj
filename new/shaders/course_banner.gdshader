shader_type spatial;
render_mode cull_disabled;
void vertex() {
	VERTEX.z += sin(TIME * 2.8 + UV.y * 6.0 + NODE_POSITION_WORLD.x * 0.05) * 0.10 * UV.x;
}
void fragment() {
	vec2 cell = vec2((UV.x - 0.5) * 2.0, fract(UV.y * 3.0) - 0.35);
	float chevron = 1.0 - smoothstep(0.065, 0.105, abs(cell.y - abs(cell.x) * 0.28));
	float edge = step(0.06, UV.x) * step(UV.x, 0.94);
	ALBEDO = mix(vec3(0.65, 0.015, 0.035), vec3(0.97, 0.95, 0.89), chevron * edge);
	ROUGHNESS = 0.85;
}
