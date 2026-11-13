shader_type spatial;
render_mode cull_disabled;
uniform vec4 rim_color : source_color = vec4(.7,.7,.7,1.);
uniform bool overlay = false;
uniform bool replace_rim = false;
uniform bool protection = false;
uniform bool use_source_texture = false;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform float protection_amount = 1.0;
void fragment(){
	vec3 source=vec3(0.);
	if(use_source_texture) source=texture(source_texture,UV).rgb;
	bool metal=overlay || (use_source_texture ? min(source.r,min(source.g,source.b))>.18 : UV.x>.45);
	if(!overlay && replace_rim && metal) discard;
	ALBEDO=metal?rim_color.rgb:(use_source_texture?source:COLOR.rgb); METALLIC=metal?.8:(use_source_texture?.04:UV.x); ROUGHNESS=metal?.24:(use_source_texture?.8:UV.y);
	if(protection){ALBEDO=mix(ALBEDO,vec3(.12,.55,.72),.65*protection_amount);EMISSION=vec3(.03,.4,.6)*protection_amount;}
}
