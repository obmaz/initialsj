shader_type spatial;
render_mode cull_disabled;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
 ALBEDO=texture(rock_detail,UV*.8).rgb;
 ROUGHNESS=.97;SPECULAR=.08;
}
