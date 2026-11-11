shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
uniform sampler2D facade_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 tile = vec2(0);
uniform vec2 metres_per_tile = vec2(6,7);
uniform bool box_uv = true;
varying vec2 facade_uv;
void vertex() {
 vec3 metres=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 vec3 size=abs(metres)*2.;
 vec2 face=abs(NORMAL.x)>.5 ? size.zy : (abs(NORMAL.y)>.5 ? size.xz : size.xy);
 vec2 p=abs(NORMAL.x)>.5 ? vec2(metres.z,-metres.y) : (abs(NORMAL.y)>.5 ? metres.xz : vec2(metres.x,-metres.y));
 facade_uv=box_uv ? (p+face*.5)/metres_per_tile : UV;
}
void fragment() {
 vec2 margin=vec2(2.)/vec2(textureSize(facade_atlas,0));
 vec2 uv=tile*.5+margin+fract(facade_uv)*(.5-2.*margin);
 ALBEDO=textureGrad(facade_atlas,uv,dFdx(facade_uv)*.49,dFdy(facade_uv)*.49).rgb;
 ROUGHNESS=.92;SPECULAR=.1;
 float height=dot(ALBEDO,vec3(.2126,.7152,.0722));
 NORMAL=relief_normal(height,VERTEX,NORMAL,.5);
 AO=mix(.72,1.0,smoothstep(.08,.5,height));AO_LIGHT_AFFECT=.65;
}
