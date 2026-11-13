shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform float outline_width : hint_range(0., .06) = .018;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = vec3(0.009, 0.016, 0.029);
}
