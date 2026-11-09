shader_type spatial;
render_mode cull_disabled;
uniform float dash_length = 5.0;
uniform float dash_period = 12.0;
uniform vec3 paint_color : source_color = vec3(0.75,0.79,0.75);
void fragment() {
	if (mod(UV.y,dash_period) > dash_length) discard;
	ALBEDO = paint_color;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
