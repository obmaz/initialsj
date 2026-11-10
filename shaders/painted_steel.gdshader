shader_type spatial;
uniform sampler2D material_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 material_tile = vec2(0.0,1.0);
uniform vec4 paint_color : source_color = vec4(1.0);
uniform float texture_scale = .5;
uniform float metalness = .35;
uniform float surface_roughness = .63;
uniform bool instance_variation = false;
uniform bool concrete_family = false;
uniform bool uv_projection = false;
varying vec2 surface_uv;
varying float instance_style;
varying vec3 world;
varying vec3 world_normal;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);instance_style=INSTANCE_CUSTOM.r;
 vec3 metres=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 surface_uv=UV*(abs(NORMAL.x)>.5 ? metres.zy : (abs(NORMAL.y)>.5 ? metres.xz : metres.xy));
}
vec3 surface_sample(vec2 p) {
 vec2 mirror=1.0-abs(mod(p,2.0)-1.0);
 vec2 margin=clamp(fwidth(p)*.5,vec2(.006),vec2(.15));
 vec2 tile=material_tile;
 if(instance_variation) tile=vec2(step(.5,instance_style),concrete_family ? 0.0 : 1.0);
 vec2 uv=tile*.5+margin+mirror*(.5-2.0*margin);
 return textureGrad(material_atlas,uv,dFdx(p)*.48,dFdy(p)*.48).rgb;
}
void fragment() {
 vec3 weights=pow(abs(world_normal),vec3(4.0));weights/=max(dot(weights,vec3(1.0)),.001);
 vec3 color;
 if(uv_projection) color=surface_sample((surface_uv+instance_style*17.0)*texture_scale);
 else color=surface_sample((world.zy+instance_style*17.0)*texture_scale)*weights.x+surface_sample((world.xz+instance_style*17.0)*texture_scale)*weights.y+surface_sample((world.xy+instance_style*17.0)*texture_scale)*weights.z;
 ALBEDO=color*paint_color.rgb;
 float height=dot(color,vec3(.2126,.7152,.0722));
 vec3 a=cross(dFdy(VERTEX),NORMAL);vec3 b=cross(NORMAL,dFdx(VERTEX));float det=dot(dFdx(VERTEX),a);
 NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(height)*a+dFdy(height)*b)*.055);
 METALLIC=metalness;ROUGHNESS=clamp(surface_roughness+(height-.3)*.15,.25,.98);SPECULAR=.35;
}
