shader_type spatial;
render_mode cull_disabled;
uniform sampler2D blossoms : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D foliage_mask : filter_linear_mipmap_anisotropic;
void fragment() {
 ALBEDO=texture(blossoms,UV).rgb;
 ROUGHNESS=.92;
 ALPHA=texture(foliage_mask,UV).a;
 ALPHA_SCISSOR_THRESHOLD=.4;
}
