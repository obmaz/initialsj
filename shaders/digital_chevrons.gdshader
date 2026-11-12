shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool animate = true;
uniform bool show_arrows = true;
uniform vec4 led_color : source_color = vec4(1.0, .64, .08, 1.0);
void fragment() {
	float phase = animate ? TIME * .72 : 0.0;
	vec2 cell = vec2(fract(UV.x * 3.0 + phase), UV.y);
	float stroke = 1.0 - smoothstep(.055, .095, abs(cell.x - (.18 + abs(cell.y - .5) * .95)));
	stroke *= step(.12, cell.y) * step(cell.y, .88);
	vec2 dot_cell = fract(UV * vec2(90.0, 45.0)) - .5;
	float dots = 1.0 - smoothstep(.28, .46, length(dot_cell));
	float light = show_arrows ? stroke * (.25 + .75 * dots) : dots * .055;
	ALBEDO = vec3(.006, .014, .021) + led_color.rgb * light;
	EMISSION = led_color.rgb * light * .8;
}
