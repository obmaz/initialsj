shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
uniform sampler2D container_skins : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D building_fronts : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D building_sides : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D restaurant_facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rural_fronts : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rural_sides : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float style;
varying float variant;
varying float front;
void vertex() { style=UV2.x;front=UV2.y;variant=INSTANCE_CUSTOM.r; }
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.94;SPECULAR=.05;
 if(style>59.5 && style<63.5) {
  float index=floor(style+.5)-60.0;
  vec2 cell=vec2(.25,.5);
  vec2 uv=vec2(index*.25,front>1.5 ? .5 : 0.0)+vec2(.0015,.003)+UV*vec2(.247,.494);
  ALBEDO=textureGrad(container_skins,uv,dFdx(UV)*cell,dFdy(UV)*cell).rgb;
  METALLIC=.2;ROUGHNESS=.84;
 } else if(style>39.5 && style<49.5) {
  float index=floor(style+.5)-40.0;
  vec2 q=UV;
  if(front>.5) q.x=1.0-q.x;
  vec2 cell=vec2(.2,.5),tile=vec2(mod(index,5.0),floor(index/5.0));
  vec2 margin=vec2(.0015,.003);
  vec2 uv=tile*cell+margin+clamp(q,vec2(0),vec2(1))*(cell-2.0*margin);
  if(front>.5) ALBEDO=textureGrad(rural_fronts,uv,dFdx(q)*cell,dFdy(q)*cell).rgb;
  else ALBEDO=textureGrad(rural_sides,uv,dFdx(q)*cell,dFdy(q)*cell).rgb;
  ROUGHNESS=.9;SPECULAR=.12;
 } else if(style>9.5) {
  float index=floor(style+.5)-10.0;
  vec2 q=UV;
  if(front>.5) q.x=1.0-q.x;
  vec2 cell=vec2(.25,1.0/3.0);
  vec2 tile=vec2(mod(index,4.0),floor(index/4.0));
  if(index>11.5) {cell=vec2(.5);tile=vec2(index-12.0,front>.5 ? 0.0 : 1.0);}
  vec2 margin=vec2(.0015,.003);
  vec2 uv=tile*cell+margin+clamp(q,vec2(0),vec2(1))*(cell-2.0*margin);
  vec3 surface;
  if(index>11.5) surface=textureGrad(restaurant_facades,uv,dFdx(q)*cell,dFdy(q)*cell).rgb;
  else if(front>.5) surface=textureGrad(building_fronts,uv,dFdx(q)*cell,dFdy(q)*cell).rgb;
  else surface=textureGrad(building_sides,uv,dFdx(q)*cell,dFdy(q)*cell).rgb;
  vec3 warm=vec3(1.04,.98,.91);vec3 cool=vec3(.93,.99,1.04);
  ALBEDO=surface*mix(warm,cool,variant);
  ROUGHNESS=.82;SPECULAR=.22;
  AO=mix(.78,1.0,smoothstep(0.0,.07,min(q.x,1.0-q.x)));
 }
 float height=dot(ALBEDO,vec3(.2126,.7152,.0722));
 NORMAL=relief_normal(height,VERTEX,NORMAL,.45);
 float foot=1.0-smoothstep(.80,1.0,UV.y);
 AO*=mix(.73,1.0,foot)*mix(.84,1.0,smoothstep(.06,.5,height));
 AO_LIGHT_AFFECT=.65;
}
