shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
varying vec3 tint;
void vertex(){
 tint=mix(vec3(.8,.18,.025),vec3(.08,.45,.29),step(.5,INSTANCE_CUSTOM.r));
 if(INSTANCE_CUSTOM.r>.8)tint=vec3(.56,.025,.2);
}
void fragment(){
 vec2 p=UV*2.-1.;
 float edge=pow(max(0.,1.-dot(p,p)),2.);
 ALBEDO=tint*.19;ALPHA=edge*.38;
}
