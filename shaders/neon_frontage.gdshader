shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
uniform sampler2D facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float zone;
varying float front;
varying float theme;
void vertex() {zone=UV2.x;front=UV2.y;theme=step(.5,INSTANCE_CUSTOM.r);}
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.86;METALLIC=.1;
 if(zone>9.5) {
  vec2 q=UV;
  if(front>.5)q.x=1.-q.x;
  bool pylon=zone>19.5;
  if(pylon)q=vec2(1.-UV.y,.42+UV.x*.14);
  vec2 tile=vec2(pylon ? 0. : (front>.5 ? 0. : .5),theme*.5);
  vec2 margin=vec2(.002);
  vec2 uv=tile+margin+clamp(q,vec2(0),vec2(1))*(.5-2.*margin);
  vec3 photo=textureGrad(facades,uv,dFdx(q)*.496,dFdy(q)*.496).rgb;
  ALBEDO=photo;
  float light=max(photo.r,max(photo.g,photo.b));
  float chroma=light-min(photo.r,min(photo.g,photo.b));
  EMISSION=photo*smoothstep(.15,.65,light)*smoothstep(.06,.35,chroma)*1.3;
  NORMAL=relief_normal(dot(photo,vec3(.2126,.7152,.0722)),VERTEX,NORMAL,.4);
 } else {
  float chroma=max(COLOR.r,max(COLOR.g,COLOR.b))-min(COLOR.r,min(COLOR.g,COLOR.b));
  EMISSION=COLOR.rgb*smoothstep(.5,.8,chroma)*1.9;
 }
 AO=.86;AO_LIGHT_AFFECT=.5;
}
