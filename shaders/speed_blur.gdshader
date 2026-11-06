shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform bool high_quality = true;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ray = uv - vec2(0.5, 0.42);
	float edge = smoothstep(0.20, 0.62, length(ray));
	vec4 sharp = texture(scene, uv);
	if (edge * strength < 0.01) {
		COLOR = sharp;
	} else {
		vec2 offset = ray * edge * strength * 0.042;
		if (!high_quality) {
			vec4 blur = sharp*0.5+texture(scene,uv-offset*0.45)*0.3+texture(scene,uv-offset)*0.2;
			COLOR = mix(sharp,blur,edge*0.85);
		} else {
		vec4 blur = sharp * 0.30;
		blur += texture(scene, uv - offset * 0.25) * 0.25;
		blur += texture(scene, uv - offset * 0.50) * 0.20;
		blur += texture(scene, uv - offset * 0.75) * 0.15;
		blur += texture(scene, uv - offset) * 0.10;
		COLOR = mix(sharp, blur, edge * 0.85);
		}
	}
}
