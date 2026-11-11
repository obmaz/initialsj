shader_type spatial;
uniform sampler2D crowd : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float printed;
varying float phase;
void vertex() { printed=UV2.x;phase=INSTANCE_CUSTOM.r; }
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.92;SPECULAR=.1;
 if(printed>.5) {
  vec3 people=texture(crowd,UV+vec2(phase*3.7,phase*.9)).rgb;
  ALBEDO=people;EMISSION=people*.09;
 }
}
