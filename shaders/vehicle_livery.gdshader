shader_type spatial;
uniform vec4 base_paint : source_color = vec4(1.);
uniform vec4 secondary_paint : source_color = vec4(.1,.7,.8,1.);
uniform sampler2D livery_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int livery = 0;
uniform int vehicle_column = 0;
uniform float finish_roughness = .25;
uniform float finish_metallic = .6;
uniform bool protection = false;
void fragment() {
	vec3 base=base_paint.rgb;
	if(livery>0) {
		vec2 cell=(vec2(float(vehicle_column),float(livery-1))+mix(vec2(.015),vec2(.985),UV))/vec2(4.,3.);
		vec3 graphic=texture(livery_atlas,cell).rgb;
		float mask=smoothstep(.025,.18,max(graphic.r,max(graphic.g,graphic.b)));
		base=mix(base,mix(graphic,secondary_paint.rgb,.15),mask);
	}
	ALBEDO=base; METALLIC=finish_metallic; ROUGHNESS=finish_roughness;
	CLEARCOAT=finish_roughness<.5 ? .85 : .05; CLEARCOAT_ROUGHNESS=.2;
	if(protection){ ALBEDO=mix(base,vec3(.12,.55,.72),.65);EMISSION=vec3(.03,.4,.6)*(.6+.15*sin(TIME*8.)); }
}
