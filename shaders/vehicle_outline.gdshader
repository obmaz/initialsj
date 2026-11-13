shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

void vertex() {
	VERTEX += NORMAL * 0.018;
}

void fragment() {
	ALBEDO = vec3(0.009, 0.016, 0.029);
}
