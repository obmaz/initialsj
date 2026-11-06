shader_type sky;

uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_disable;
uniform float center_yaw = 2.007129;
uniform float horizontal_span = 2.094395;
uniform float vertical_span = 1.047198;
uniform float horizon_uv = 0.51;

void sky() {
	float azimuth = atan(EYEDIR.x, EYEDIR.z);
	float relative = atan(sin(azimuth - center_yaw), cos(azimuth - center_yaw));
	float u = 0.5 + relative / horizontal_span;
	float v = clamp(horizon_uv - asin(clamp(EYEDIR.y, -1.0, 1.0)) / vertical_span, 0.005, 0.995);
	// Peripheral foothills fill the rest of the horizon without repeating Mount Fuji.
	float back_progress = clamp((abs(relative) - horizontal_span * 0.5) / (3.141593 - horizontal_span * 0.5), 0.0, 1.0);
	vec3 left_hills = texture(panorama, vec2(mix(0.14, 0.28, back_progress), v)).rgb;
	vec3 right_hills = texture(panorama, vec2(mix(0.98, 0.72, back_progress), v)).rgb;
	vec3 peripheral = relative < 0.0 ? left_hills : right_hills;
	float rear_blend = smoothstep(2.94, 3.141593, abs(relative));
	peripheral = mix(peripheral, (left_hills + right_hills) * 0.5, rear_blend);
	vec3 front = texture(panorama, vec2(clamp(u, 0.005, 0.995), v)).rgb;
	float front_weight = 1.0 - smoothstep(0.44, 0.50, abs(u - 0.5));
	COLOR = mix(peripheral, front, front_weight);
}
