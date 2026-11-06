shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
void fragment() {
	float edge = 1.0 - smoothstep(0.025,0.055,min(UV.x,1.0-UV.x));
	edge = max(edge,1.0-smoothstep(0.015,0.035,min(UV.y,1.0-UV.y)));
	float phase = fract(UV.y*4.0-TIME*1.1);
	float tip = 0.72-abs(UV.x-0.5)*0.8;
	float arrow = (1.0-smoothstep(0.065,0.11,abs(phase-tip)))*step(0.14,UV.x)*step(UV.x,0.86);
	vec3 color = mix(vec3(0.025,0.12,0.17),vec3(0.12,0.85,1.0),edge);
	color = mix(color,vec3(1.0,0.82,0.20),arrow);
	ALBEDO = color*(0.95+0.05*sin(TIME*3.0));
}
