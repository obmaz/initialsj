shader_type spatial;
render_mode cull_disabled;
uniform sampler2D rock_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 w=pow(abs(world_normal),vec3(4.0));w/=max(w.x+w.y+w.z,0.001);
 vec4 rock=texture(rock_detail,world_position.zy*.12)*w.x+texture(rock_detail,world_position.xz*.12)*w.y+texture(rock_detail,world_position.xy*.12)*w.z;
 float band=sin(world_position.y*.19+sin(world_position.x*.013)*1.6+sin(world_position.z*.018)*1.3);
 float stain=sin(world_position.x*.051+sin(world_position.z*.063))*sin(world_position.y*.047);
 ALBEDO=rock.rgb*(.92+.055*band+.045*stain);
 vec3 a=cross(dFdy(VERTEX),NORMAL);vec3 b=cross(NORMAL,dFdx(VERTEX));
 float det=dot(dFdx(VERTEX),a);
 NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(rock.a)*a+dFdy(rock.a)*b)*.10);
 ROUGHNESS=.93;SPECULAR=.04;
}
