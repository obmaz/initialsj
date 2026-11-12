shader_type spatial;
uniform sampler2D ad_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 ad_tile = vec2(0.0);
uniform float night_lighting = 0.0;
uniform vec2 ad_grid = vec2(2.0);
void fragment() {
	vec2 inset = vec2(2.0) / vec2(textureSize(ad_atlas, 0));
	vec2 uv = ad_tile / ad_grid + inset + UV * (1.0 / ad_grid - inset * 2.0);
	vec3 ink = textureGrad(ad_atlas, uv, dFdx(UV) / ad_grid, dFdy(UV) / ad_grid).rgb;
	ALBEDO = ink;
	ROUGHNESS = 0.78;
	EMISSION = ink * mix(.15,.8,night_lighting);
}
