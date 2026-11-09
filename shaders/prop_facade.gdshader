shader_type spatial;
uniform sampler2D retail_facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D urban_facades : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ad_prints : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float style;
varying float variant;
varying float front;
void vertex() { style=UV2.x;front=UV2.y;variant=INSTANCE_CUSTOM.r; }
void fragment() {
 ALBEDO=COLOR.rgb;ROUGHNESS=.94;SPECULAR=.05;
 if(style>17.5) {
  float ad=floor(min(variant,.999)*8.0);
  vec2 tile=vec2(mod(ad,4.0),floor(ad/4.0));
  ALBEDO=texture(ad_prints,tile*vec2(.25,.5)+vec2(.002)+UV*vec2(.246,.496)).rgb;
  ROUGHNESS=.75;
 } else if(style>9.5) {
  float index=floor(style+.5)-10.0;bool urban=index>3.5;
  if(urban) index-=4.0;
  vec2 q=UV;
  if(urban) q=fract(UV*(index>2.5 ? vec2(3.0,1.0) : vec2(4.0,5.0)));
  else if(front<.5) q=vec2(.04)+UV*.10;
  vec2 tile=vec2(mod(index,2.0),floor(index/2.0));
  vec2 margin=clamp(fwidth(q)*.5,vec2(.005),vec2(.08));
  vec2 uv=tile*.5+margin+clamp(q,vec2(0),vec2(1))*(.5-2.0*margin);
  vec3 surface=urban ? texture(urban_facades,uv).rgb : texture(retail_facades,uv).rgb;
  vec3 warm=vec3(1.04,.98,.91);vec3 cool=vec3(.93,.99,1.04);
  ALBEDO=surface*mix(warm,cool,variant);
  ROUGHNESS=.78;SPECULAR=.25;
 }
}
