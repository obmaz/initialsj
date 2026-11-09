shader_type spatial;
uniform sampler2D ad_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 ad_tile = vec2(0.0);
void fragment() {
	vec2 inset = vec2(2.0) / vec2(textureSize(ad_atlas, 0));
	vec2 uv = ad_tile * 0.5 + inset + UV * (0.5 - inset * 2.0);
	vec3 ink = textureGrad(ad_atlas, uv, dFdx(UV) * 0.5, dFdy(UV) * 0.5).rgb;
	ALBEDO = ink;
	ROUGHNESS = 0.78;
	EMISSION = ink * 0.15;
}
