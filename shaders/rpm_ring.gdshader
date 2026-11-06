shader_type canvas_item;
render_mode unshaded;
uniform float rpm_ratio = 0.0;
void fragment() {
	if (UV.x > rpm_ratio) discard;
	COLOR = COLOR;
}
