shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float leaf;
void vertex() { leaf=UV2.x; }
void fragment() {
 vec4 ink=leaf>.5 ? texture(leaves,UV) : vec4(texture(bark,UV).rgb,1.);
 ALBEDO=ink.rgb*COLOR.rgb;
 ALPHA=ink.a;
 ALPHA_SCISSOR_THRESHOLD=.42;
 ROUGHNESS=.96;SPECULAR=.06;
}
