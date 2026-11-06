shader_type sky;
// Location photos are a temporary horizon backdrop, not a reconstructed panorama.
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D photo_previous : source_color, filter_linear_mipmap, repeat_disable;
uniform float center_yaw = 0.0;
uniform float previous_yaw = 0.0;
uniform float photo_blend = 1.0;
vec3 backdrop(sampler2D source,vec3 direction,float yaw) {
	float angle = atan(direction.x,direction.z)-yaw;
	float relative = atan(sin(angle),cos(angle));
	float u = 0.5-relative/2.75;
	float v = clamp(0.65-asin(clamp(direction.y,-1.0,1.0))/0.60,0.01,0.99);
	vec3 image_color = texture(source,vec2(clamp(u,0.015,0.985),v)).rgb;
	vec3 haze = vec3(0.67,0.76,0.79);
	vec3 sky_color = mix(haze,vec3(0.31,0.54,0.69),smoothstep(0.0,0.85,direction.y));
	float edges = 1.0-smoothstep(0.4,0.5,abs(u-0.5));
	float top = 1.0-smoothstep(0.20,0.43,direction.y);
	return mix(sky_color,mix(image_color,haze,0.16),edges*top);
}
void sky() {
	COLOR = mix(backdrop(photo_previous,EYEDIR,previous_yaw),backdrop(photo,EYEDIR,center_yaw),smoothstep(0.0,1.0,photo_blend));
}
