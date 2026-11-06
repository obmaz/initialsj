shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D lake_image : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	vec2 uv = 1.0 - abs(fract(p / 100.0) * 2.0 - 1.0);
	vec3 lake = texture(lake_image, vec2(uv.x, 0.66 + uv.y * 0.32)).rgb;
	float ripple = sin(p.x * 1.1 + p.y * 0.7 + TIME * 0.9) * sin(p.y * 0.85 - TIME * 0.65);
	float calm = 1.0 / (1.0 + length(VERTEX) * 0.025);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	ALBEDO = mix(lake * 0.68, vec3(0.16, 0.34, 0.44), fresnel * 0.30);
	NORMAL_MAP = normalize(vec3(ripple * calm * 0.055, cos(p.x + TIME * 0.3) * calm * 0.03, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.29;
	SPECULAR = 0.48;
	METALLIC = 0.0;
}
