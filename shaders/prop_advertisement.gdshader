shader_type spatial;
uniform sampler2D ad_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 ad_tile = vec2(0);
uniform vec2 ad_grid = vec2(3,2);
varying float front;
varying float printed_face;
varying float print_fill;
void vertex() { front=UV2.y;printed_face=UV2.x;print_fill=INSTANCE_CUSTOM.g; }
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.86;SPECULAR=.1;
 if(printed_face>29.5) {
  vec2 q=UV;
  if(front>.5) q.x=1.0-q.x;
  vec2 inset=vec2(2.0)/vec2(textureSize(ad_atlas,0));
  vec2 uv=ad_tile/ad_grid+inset+q*(1.0/ad_grid-inset*2.0);
  ALBEDO=textureGrad(ad_atlas,uv,dFdx(q)/ad_grid,dFdy(q)/ad_grid).rgb;
  // 인쇄면만 보조광을 보정한다. 뒷판·지주는 실제 조명을 유지한다.
  EMISSION=ALBEDO*max(.1,print_fill);
 }
}
