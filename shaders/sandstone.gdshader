shader_type spatial;
render_mode cull_disabled;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
vec3 atlas_sample(vec2 p) {
 vec2 q=fract(p);
 vec2 margin=clamp(fwidth(p)*.5,vec2(.006),vec2(.15));
 return textureGrad(rock_detail,margin+q*(.5-2.0*margin),dFdx(p)*.48,dFdy(p)*.48).rgb;
}
vec3 rock_sample(vec2 p) {
 p+=vec2(sin(p.y*.63),sin(p.x*.47))*.17;
 vec2 q=fract(p);vec2 shifted=fract(p+.5);
 vec2 a=sin(q*3.14159265);vec2 b=sin(shifted*3.14159265);
 float wa=a.x*a.x*a.y*a.y+.001;float wb=b.x*b.x*b.y*b.y+.001;
 return (atlas_sample(p)*wa+atlas_sample(p+.5)*wb)/(wa+wb);
}
void fragment() {
 vec3 w=pow(abs(world_normal),vec3(4.0));w/=max(w.x+w.y+w.z,.001);
 vec3 rock=rock_sample(world_position.zy*.12)*w.x+rock_sample(world_position.xz*.12)*w.y+rock_sample(world_position.xy*.12)*w.z;
 float stain=sin(world_position.x*.027+sin(world_position.z*.033))*sin(world_position.y*.021);
 ALBEDO=rock*(.97+.045*stain);
 float height=dot(rock,vec3(.2126,.7152,.0722));
 vec3 a=cross(dFdy(VERTEX),NORMAL);vec3 b=cross(NORMAL,dFdx(VERTEX));float det=dot(dFdx(VERTEX),a);
 NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(height)*a+dFdy(height)*b)*.12);
 ROUGHNESS=.94;SPECULAR=.08;
}
