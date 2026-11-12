shader_type spatial;
render_mode cull_disabled;
uniform vec4 rim_color : source_color = vec4(.7,.7,.7,1.);
uniform bool overlay = false;
uniform bool replace_rim = false;
uniform bool protection = false;
uniform float protection_amount = 1.0;
void fragment(){
	bool metal=overlay || UV.x>.45;
	if(!overlay && replace_rim && metal) discard;
	ALBEDO=metal?rim_color.rgb:COLOR.rgb; METALLIC=metal?.8:UV.x; ROUGHNESS=metal?.24:UV.y;
	if(protection){ALBEDO=mix(ALBEDO,vec3(.12,.55,.72),.65*protection_amount);EMISSION=vec3(.03,.4,.6)*protection_amount;}
}
