shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 rock_tint : source_color = vec4(1.);
uniform float rock_saturation = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
vec3 atlas_sample(vec2 p, vec2 tile) {
 vec2 q=fract(p);
 vec2 margin=clamp(fwidth(p)*.5,vec2(.006),vec2(.15));
 return textureGrad(rock_detail,tile*.5+margin+q*(.5-2.0*margin),dFdx(p)*.48,dFdy(p)*.48).rgb;
}
vec3 rock_sample(vec2 p, vec2 tile) {
 p+=vec2(sin(p.y*.63),sin(p.x*.47))*.17;
 vec2 q=fract(p);vec2 shifted=fract(p+.5);
 vec2 a=sin(q*3.14159265);vec2 b=sin(shifted*3.14159265);
 float wa=a.x*a.x*a.y*a.y+.001;float wb=b.x*b.x*b.y*b.y+.001;
 return (atlas_sample(p,tile)*wa+atlas_sample(p+.5,tile)*wb)/(wa+wb);
}
vec2 rock_tile(float index) { return vec2(mod(index,2.0),floor(index/2.0)); }
vec3 triplanar_rock(vec3 p, vec3 w, vec2 tile) {
 return rock_sample(p.zy*.12,tile)*w.x+rock_sample(p.xz*.12,tile)*w.y+rock_sample(p.xy*.12,tile)*w.z;
}
void fragment() {
 vec3 w=pow(abs(world_normal),vec3(4.0));w/=max(w.x+w.y+w.z,.001);
 // 수백 m 지질 구간과 높이에 따른 층리를 함께 사용합니다. 프레임마다 변하지 않습니다.
 float geology=clamp(1.5+sin(world_position.x*.004+world_position.z*.003)*1.18+sin(world_position.y*.052+sin(world_position.x*.009))*.59,0.0,2.999);
 float base=floor(geology);float next=min(base+1.0,3.0);
 float transition=smoothstep(.12,.88,fract(geology));
 vec3 rock=mix(triplanar_rock(world_position,w,rock_tile(base)),triplanar_rock(world_position,w,rock_tile(next)),transition);
 float stain=sin(world_position.x*.027+sin(world_position.z*.033))*sin(world_position.y*.021);
 rock=mix(vec3(dot(rock,vec3(.2126,.7152,.0722))),rock,rock_saturation)*rock_tint.rgb;
 ALBEDO=rock*(.97+.045*stain);
 float height=dot(rock,vec3(.2126,.7152,.0722));
 NORMAL=relief_normal(height,VERTEX,NORMAL,.85);
 AO=mix(.62,1.0,smoothstep(.08,.5,height));AO_LIGHT_AFFECT=.7;
 ROUGHNESS=clamp(.82+height*.22,.82,.98);SPECULAR=.2;
}
