shader_type spatial;
render_mode diffuse_burley;
uniform vec4 deep_color : source_color = vec4(0.025,0.26,0.44,1);
uniform vec4 shallow_color : source_color = vec4(0.08,0.51,0.65,1);
uniform sampler2D surface_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1)).xyz; }
void fragment() {
	// Unequal, non-perpendicular swells avoid a regular checkerboard at speed.
	float a = world.x*0.047+world.z*0.031+TIME*0.7;
	float b = world.x*0.019-world.z*0.063-TIME*0.53;
	float c = world.x*0.113+world.z*0.072+TIME*1.1;
	float wave = sin(a)*0.5+sin(b)*0.32+sin(c)*0.18;
	vec3 normal_world = normalize(vec3(-cos(a)*0.025-cos(c)*0.012,1.0,-cos(b)*0.035-cos(c)*0.008));
	NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	float horizon = pow(1.0-max(dot(NORMAL,normalize(VIEW)),0.0),3.0);
	vec3 water = mix(deep_color.rgb,shallow_color.rgb,0.52+wave*0.14);
 vec3 first=texture(surface_detail,world.xz*.04+vec2(TIME*.004,-TIME*.003)).rgb;
 vec3 second=texture(surface_detail,world.zx*.027+vec2(-TIME*.002,TIME*.004)).rgb;
 float detail=dot((first+second)*.5,vec3(.2126,.7152,.0722));
 float foam=smoothstep(.23,.43,max(first.r,second.r))*smoothstep(-.2,.8,wave);
 water=mix(water,(first+second)*1.1,.45);
 vec3 reflection=mix(vec3(.16,.34,.48),vec3(.62,.78,.85),horizon);
 ALBEDO=mix(mix(water*(.85+detail*.3),reflection,horizon*.65),vec3(.78,.87,.86),foam*.65);
	ROUGHNESS = mix(.18,.38,detail);
	SPECULAR = 0.55;
}
