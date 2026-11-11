shader_type spatial;
uniform sampler2D crowd : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float printed;
varying float phase;
void vertex() { printed=UV2.x;phase=INSTANCE_CUSTOM.r; }
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.92;SPECULAR=.1;
 if(printed>.5 && printed<1.5) {
  vec3 people=texture(crowd,UV+vec2(phase*3.7,phase*.9)).rgb;
  ALBEDO=people;EMISSION=people*.09;
 } else if(printed>1.5) {
  vec2 tile=printed<2.5 ? vec2(1,0) : vec2(1,1);
  vec2 margin=vec2(2.)/vec2(textureSize(facades,0));
  vec2 uv=tile*.5+margin+fract(UV)*(.5-2.*margin);
  ALBEDO=textureGrad(facades,uv,dFdx(UV)*.49,dFdy(UV)*.49).rgb;
 }
}
