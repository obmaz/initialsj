shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 row_bounds = vec2(0,.185);
uniform float night_lighting = 0.0;
void fragment() {
 vec2 inset=vec2(2.)/vec2(textureSize(atlas,0));
 vec2 span=vec2(1.,row_bounds.y-row_bounds.x)-2.*inset;
 vec2 uv=vec2(0,row_bounds.x)+inset+UV*span;
 vec3 ink=textureGrad(atlas,uv,dFdx(UV)*span,dFdy(UV)*span).rgb;
 ALBEDO=ink;EMISSION=ink*mix(.55,.85,night_lighting);ROUGHNESS=.85;SPECULAR=.08;
}
