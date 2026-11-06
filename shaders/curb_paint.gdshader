shader_type spatial;
render_mode cull_disabled;
uniform vec4 red_color : source_color;
uniform vec4 white_color : source_color;
void fragment() {
	ALBEDO = mix(red_color.rgb,white_color.rgb,mod(floor(UV.y/3.0),2.0));
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
