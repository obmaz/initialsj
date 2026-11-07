shader_type sky;

// Three panels around the full horizon, each drawn at the same pixel scale:
// the generated panorama covers the 120 degrees around Mount Fuji; two baked
// rear panels (tools/bake_fuji_backdrop.py) cover the remaining 240 degrees.
// The textures are only ever magnified on screen, so plain linear filtering is
// used and no mip level can mark the joins between panels.
uniform sampler2D panorama : source_color, filter_linear, repeat_disable;
uniform sampler2D back_a : source_color, filter_linear, repeat_disable;
uniform sampler2D back_b : source_color, filter_linear, repeat_disable;
uniform float center_yaw = 2.007129;
uniform float horizontal_span = 2.094395;
uniform float vertical_span = 1.047198;
uniform float horizon_uv = 0.51;

void sky() {
	float azimuth = atan(EYEDIR.x, EYEDIR.z);
	float relative = atan(sin(azimuth - center_yaw), cos(azimuth - center_yaw));
	float v = clamp(horizon_uv - asin(clamp(EYEDIR.y, -1.0, 1.0)) / vertical_span, 0.0, 1.0);
	float half_span = horizontal_span * 0.5;
	if (abs(relative) <= half_span) {
		COLOR = texture(panorama, vec2(0.5 + relative / horizontal_span, v)).rgb;
	} else {
		// The rear strip runs left to right from the panorama's right edge,
		// round the back, to its left edge.
		float around = relative > 0.0 ? relative - half_span : relative + 6.283185 - half_span;
		float b = around / (6.283185 - horizontal_span);
		COLOR = b < 0.5 ? texture(back_a, vec2(b * 2.0, v)).rgb : texture(back_b, vec2(b * 2.0 - 1.0, v)).rgb;
	}
}
