shader_type spatial;
#include "res://shaders/surface_relief.gdshaderinc"
uniform sampler2D facade_images : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D facade_extra : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool ruined = false;
uniform bool night_city = false;
uniform bool industrial_facade = false;
uniform int facade_style = 0;
uniform int regional_style = 0;
varying vec3 local_point;
varying vec3 local_normal;
varying vec4 dimensions;
void vertex() {
	local_point = VERTEX;
	local_normal = NORMAL;
	dimensions = INSTANCE_CUSTOM;
}
void fragment() {
	bool side = abs(local_normal.x) > 0.5;
	float u = side ? local_point.z * dimensions.z : local_point.x * dimensions.x;
	if (facade_style == 3) { u = atan(local_point.z,local_point.x)*dimensions.x*0.5; }
	float v = local_point.y * dimensions.y;
	vec2 cell = fract(vec2(u / (facade_style == 1 ? 1.8 : 3.2), v / (facade_style == 5 ? 2.8 : 4.0)));
	float pane = smoothstep(0.13,0.18,cell.x) * (1.0-smoothstep(0.77,0.82,cell.x));
	pane *= smoothstep(0.18,0.23,cell.y) * (1.0-smoothstep(0.70,0.75,cell.y));
	pane *= 1.0-step(0.5,abs(local_normal.y));
	float floor_line = 1.0-smoothstep(0.015,0.045,abs(cell.y-0.02));
	float module = industrial_facade ? 6.0+min(5.0,floor(dimensions.a*6.0)) : float(facade_style);
	bool extra=facade_style>=6 && !industrial_facade;
	if(extra) module-=6.0;
	vec2 tile=vec2(mod(module,4.0),floor(module/4.0));
	float width=side ? dimensions.z : dimensions.x;
	vec2 q=vec2(fract((u+width*.5)/max(16.0,min(width,28.0))),fract((.5-local_point.y)*max(1.0,dimensions.y/12.0)));
	if (industrial_facade) q=vec2(fract((u+width*.5)/width),clamp(.5-local_point.y,0.0,1.0));
	vec2 uv=tile*vec2(.25,1.0/3.0)+vec2(.002,.004)+q*vec2(.246,1.0/3.0-.008);
	vec3 photographed=extra ? texture(facade_extra,uv).rgb : texture(facade_images,uv).rgb;
	if (ruined) {
		float seed = fract(sin(floor(u/3.2)*12.9898+dimensions.a*77.0)*43758.5453);
		float top = dimensions.y*(0.28+seed*0.20);
		if (v > top || (pane > 0.3 && seed > 0.18)) { discard; }
		float grime = fract(sin(dot(floor(vec2(u,v)*2.0),vec2(12.9,78.2)))*43758.5);
		ALBEDO = photographed*vec3(.53,.50,.44)*(0.8+grime*0.35);
		ROUGHNESS = 0.95;
		METALLIC = 0.0;
	} else {
	vec3 concrete = mix(vec3(0.28,0.33,0.36),vec3(0.53,0.48,0.40),dimensions.a);
	if (facade_style == 0) { concrete = mix(vec3(0.39,0.20,0.13),vec3(0.63,0.48,0.32),dimensions.a); }
	if (facade_style == 1) { concrete = vec3(0.15,0.25,0.34); pane = max(pane,0.75); }
	if (facade_style == 2) { concrete = vec3(0.71,0.70,0.64); }
	if (facade_style == 3) { concrete = vec3(0.27,0.23,0.34); }
	if (facade_style == 4) { concrete = mix(vec3(0.51,0.58,0.55),vec3(0.30,0.40,0.39),dimensions.a); }
	if (facade_style == 5) { concrete = mix(vec3(0.66,0.57,0.39),vec3(0.53,0.37,0.25),dimensions.a); }
	if (regional_style == 1) {
		concrete = mix(concrete,vec3(0.66,0.69,0.66),0.45);
		if (facade_style == 2) {
			float balcony = 1.0-smoothstep(0.08,0.12,cell.y);
			concrete = mix(vec3(0.72,0.73,0.68),vec3(0.29,0.39,0.43),balcony);
		}
	}
	if (regional_style == 2) { concrete *= vec3(0.65,0.71,0.84); }
	vec3 glass = mix(vec3(0.12,0.24,0.32),vec3(0.41,0.60,0.69),fract(floor(u/3.2)*0.37+floor(v/4.0)*0.21+dimensions.a));

	vec3 variant_tint=mix(vec3(1.12,.93,.81),vec3(.79,.97,1.14),dimensions.a);
	ALBEDO = photographed*variant_tint;
	if(abs(local_normal.y)>.5) ALBEDO=concrete;
	float glass_mask=pane*(1.0-smoothstep(.2,.48,dot(photographed,vec3(.3,.59,.11))));
	METALLIC = glass_mask * 0.32;
	ROUGHNESS = mix(0.88,0.28,glass_mask);
	EMISSION = glass*pane*(night_city ? 0.7 : 0.07);
	if (night_city) {
		float room = fract(sin(dot(floor(vec2(u/3.2,v/4.0)),vec2(12.98,78.23))+dimensions.a*17.0)*43758.5);
		vec3 window_light = mix(vec3(0.85,0.42,0.12),vec3(0.08,0.55,0.85),step(0.5,dimensions.a));
		ALBEDO *= industrial_facade ? .95 : .55;
		EMISSION = window_light*pane*step(0.42,room)*0.95;
		if (industrial_facade) {
			float glow=max(photographed.r,photographed.b)-photographed.g*.5;
			EMISSION=photographed*smoothstep(.25,.65,glow)*1.1;
		}
		EMISSION += mix(vec3(0.15,0.03,0.24),vec3(0.02,0.25,0.34),dimensions.a)*floor_line;
	}
	}
	float luma=dot(photographed,vec3(.2126,.7152,.0722));
	float wall=1.0-step(.5,abs(local_normal.y));
	NORMAL=relief_normal(luma,VERTEX,NORMAL,.48*wall);
	float foot=smoothstep(0.0,2.4,(local_point.y+.5)*dimensions.y);
	AO=mix(.58,1.0,foot)*mix(.78,1.0,smoothstep(.08,.5,luma));
	AO_LIGHT_AFFECT=.7;
}
