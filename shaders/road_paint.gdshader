shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool harbor_corridor=false;
uniform vec4 paint_color : source_color = vec4(0.87, 0.84, 0.69, 1.0);
void fragment() {
	if(harbor_corridor && UV.y*6.0>1300.0 && UV.y*6.0<1750.0) discard;
	float grit = texture(asphalt_texture, UV * 1.3).r;
	float chips = smoothstep(0.027, 0.065, grit);
	ALBEDO = mix(vec3(0.12, 0.115, 0.105), paint_color.rgb, 0.65 + 0.35 * chips);
	ROUGHNESS = 0.91;
	SPECULAR = 0.20;
}
