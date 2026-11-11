shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
uniform sampler2D facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float zone;
varying float appearance;
void vertex(){zone=UV2.x;appearance=INSTANCE_CUSTOM.r;}
void fragment(){
 ALBEDO=COLOR.rgb;ROUGHNESS=.84;METALLIC=.12;
 if(zone>9.5){
  // MultiMesh의 반정밀도 저장 오차로 이웃 이미지가 선택되지 않게 반올림한다.
  float index=clamp(floor(appearance*12.+.5),0.,11.);
  vec2 tile=vec2(mod(index,4.),floor(index/4.));
  vec2 q=UV;
  if(zone>19.5) q=vec2(mix(.79,.985,UV.x),mix(.26,.81,UV.y));
  vec2 cell=vec2(.25,1./3.);
  vec2 uv=tile*cell+vec2(.002)+clamp(q,vec2(0),vec2(1))*(cell-vec2(.004));
  vec3 photo=textureGrad(facades,uv,dFdx(q)*(cell-.004),dFdy(q)*(cell-.004)).rgb;
  float peak=max(photo.r,max(photo.g,photo.b));
  float chroma=peak-min(photo.r,min(photo.g,photo.b));
  ALBEDO=photo*.85;
  EMISSION=photo*smoothstep(.18,.74,peak)*mix(.65,1.6,smoothstep(.1,.4,chroma));
  if(zone>19.5) EMISSION*=1.35;
  NORMAL=relief_normal(dot(photo,vec3(.2126,.7152,.0722)),VERTEX,NORMAL,.38);
 }else if(zone>1.5){
  vec3 accent=mix(vec3(1.,.13,.04),vec3(.12,.78,.48),step(.5,appearance));
  if(appearance>.8) accent=vec3(.83,.06,.37);
  ALBEDO=accent*.5;EMISSION=accent*1.5;
 }
 AO=.8;AO_LIGHT_AFFECT=.55;
}
