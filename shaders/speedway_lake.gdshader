shader_type spatial;
uniform sampler2D surface_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 lake_center = vec2(-31.2,-177.45);
uniform vec2 lake_half_size = vec2(374.4,99.45);
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
 vec2 a=world.xz*.055+vec2(TIME*.002,-TIME*.0015);
 vec2 b=world.zx*.038+vec2(-TIME*.001,TIME*.002);
 vec3 detail=(texture(surface_detail,a).rgb+texture(surface_detail,b).rgb)*.5;
 float wave=sin(world.x*.13+world.z*.08+TIME*.8)*.6+sin(world.z*.19-world.x*.04-TIME*.57)*.4;
 vec3 n=normalize(vec3(cos(world.x*.13+TIME*.8)*.025,1.,sin(world.z*.19-TIME*.57)*.025));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 vec2 q=abs((world.xz-lake_center)/lake_half_size);
 float rim=pow(pow(q.x,4.)+pow(q.y,4.),.25);
 vec3 water=mix(vec3(.025,.13,.21),vec3(.08,.34,.34),smoothstep(.78,1.,rim));
 ALBEDO=water*(.85+dot(detail,vec3(.333))*1.1)+wave*.009;
 ROUGHNESS=.18+detail.g*.15;METALLIC=.12;SPECULAR=.7;
}
