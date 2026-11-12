shader_type spatial;
render_mode cull_disabled;
uniform bool night = false;
void fragment() {
	ALBEDO = vec3(.94, .79, .30);
	ROUGHNESS = .94;
	SPECULAR = .1;
	EMISSION = night ? vec3(.16, .12, .025) : vec3(0.0);
}
