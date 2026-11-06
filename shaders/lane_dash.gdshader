shader_type spatial;
render_mode cull_disabled;
void fragment() {
	if (mod(UV.y,12.0) > 5.0) discard;
	ALBEDO = vec3(0.75,0.79,0.75);
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
