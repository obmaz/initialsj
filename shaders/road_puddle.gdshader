shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float radius = length((UV-0.5)*2.0);
	float edge = 1.0-smoothstep(0.80,1.0,radius);
	float sheen = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),3.0);
	float waves = sin(UV.y*46.0+sin(UV.x*19.0)*1.6+TIME*1.5);
	float ripple = pow(0.5+0.5*waves,20.0)*smoothstep(0.2,0.85,sheen);
	vec3 color = mix(vec3(0.09,0.22,0.28),vec3(0.40,0.59,0.67),sheen*0.8);
	color += vec3(0.12,0.17,0.18)*ripple;
	ALBEDO = color;
	ALPHA = edge*(0.62+0.16*sheen);
}
