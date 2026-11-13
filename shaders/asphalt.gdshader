shader_type spatial;
uniform vec3 stylized_rim_tint = vec3(0.015, 0.035, 0.055);
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D asphalt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_variants : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
#include "res://shaders/ground_variety.gdshaderinc"
uniform bool harbor_corridor=false;
uniform sampler2D yard_gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rain_wetness = 0.0;
uniform sampler2D wet_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wet_back_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D wet_back_b : source_color, filter_linear_mipmap, repeat_disable;
uniform bool wet_fuji = false;
uniform bool wet_reflection_ready = false;
uniform vec3 wet_sky_tint : source_color = vec3(.7,.8,.9);
uniform vec3 contact_normal = vec3(0,1,0);
uniform float wet_horizon_offset = 0.0;
uniform vec3 contact_position = vec3(0);
uniform vec2 contact_forward = vec2(0,-1);
uniform float contact_strength = 0.0;
uniform sampler2D street_pool_lookup : filter_linear, repeat_disable;
uniform float course_length = 3000.0;
uniform float street_spacing = 0.0;
uniform float street_lighting = 0.0;
uniform bool entry_surface = false;
varying float entry_shoulder;
varying vec3 world_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; entry_shoulder=COLOR.a; }
void fragment() {
	vec3 aggregate = gv_surface(asphalt_variants,world_position.xz,2.56,vec2(2),vec2(0));
	float patches = noise(world_position.xz * 0.18);
	ALBEDO = aggregate * vec3(0.87, 0.91, 1.10) * mix(0.88, 1.12, patches);
	ROUGHNESS = 0.82 + patches * 0.12;
	SPECULAR = 0.28;
	float puddles=0.0;
	if(rain_wetness>.01) puddles=smoothstep(.34,.66,noise(world_position.xz*.095+vec2(7.2,3.8)));
	ALBEDO *= mix(1.0,mix(.56,.40,puddles),rain_wetness);
	ROUGHNESS = mix(ROUGHNESS,mix(.30,.055,puddles),rain_wetness);
	SPECULAR = mix(SPECULAR,.72,rain_wetness);
	CLEARCOAT=rain_wetness*.9;
	CLEARCOAT_ROUGHNESS=.08;
	float pool=0.0;
	if(street_spacing>1.0 && street_lighting>.01) {
		vec2 lookup=texture(street_pool_lookup,vec2(fract(UV.y*6.0/course_length),.5)).rg;
		float side=lookup.g*2.0-1.0;
		float across=(UV.x-side*.65)/1.4;
		pool=lookup.r*exp(-across*across)*street_lighting;
		ALBEDO+=vec3(.35,.29,.18)*pool;
	}
	EMISSION=vec3(.15,.12,.075)*pool;
	if(rain_wetness>.01 && wet_reflection_ready) {
		vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
		vec3 ray=reflect(normalize(world_position-INV_VIEW_MATRIX[3].xyz),n);
		ray.xz+=vec2(patches-.5,noise(world_position.xz*.27)-.5)*.022;
		ray=normalize(ray);
		float azimuth=atan(ray.x,ray.z);
		vec3 reflected;
		if(wet_fuji) {
			float relative=atan(sin(azimuth-2.007129),cos(azimuth-2.007129));
			float v=clamp(.51-asin(clamp(ray.y,-1.0,1.0))/1.047198,0.0,1.0);
			if(abs(relative)<=1.047198) reflected=textureLod(wet_panorama,vec2(.5+relative/2.094395,v),1.0).rgb;
			else {
				float around=relative>0.0?relative-1.047198:relative+6.283185-1.047198;
				float b=around/4.18879;
				reflected=b<.5?textureLod(wet_back_a,vec2(b*2.0,v),1.0).rgb:textureLod(wet_back_b,vec2(b*2.0-1.0,v),1.0).rgb;
			}
		} else {
			reflected=textureLod(wet_panorama,vec2(azimuth/6.283185+.5,clamp(acos(clamp(ray.y,-1.0,1.0))/3.141593+wet_horizon_offset,.001,.999)),2.0).rgb;
		}
		float fresnel=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
		float rim = fresnel;
		EMISSION+=reflected*wet_sky_tint*rain_wetness*mix(.05,.36,puddles)*(.25+.75*rim);
		EMISSION+=vec3(.9,.72,.4)*pool*puddles*.65;
	}
	// 스타일라이즈드 2D 애니메 림 반사 (차량 셰이더와 조명 톤 일체화)
	float track_rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	EMISSION += stylized_rim_tint * track_rim;
	METALLIC = 0.0;
	if(harbor_corridor){
		float d=UV.y*6.0;
		float blend=smoothstep(1300.0,1360.0,d)*(1.0-smoothstep(1690.0,1750.0,d));
		vec3 gravel=texture(yard_gravel,world_position.xz*.37).rgb;
		float ruts=pow(max(0.0,cos(world_position.x*.31+world_position.z*.06)),8.0);
		ALBEDO=mix(ALBEDO,gravel*vec3(.71,.68,.62)*mix(.85,1.1,patches)*(1.0-.08*ruts),blend);
		ROUGHNESS=mix(ROUGHNESS,.98,blend);
		SPECULAR=mix(SPECULAR,.12,blend);
	}
	float h = dot(texture(asphalt_texture,UV).rgb, vec3(0.333));
	float hx = dot(texture(asphalt_texture, UV + vec2(0.001, 0)).rgb, vec3(0.333));
	float hy = dot(texture(asphalt_texture, UV + vec2(0, 0.001)).rgb, vec3(0.333));
	float bump=mix(.65,.17,rain_wetness*puddles);
	NORMAL_MAP = normalize(vec3((h - hx) * bump, (h - hy) * bump, 1.0)) * 0.5 + 0.5;
	// 실제 접지 위치에만 차체·타이어 접촉 음영을 둬 젖은 반사가 차 밑을 통과하지 않게 한다.
	vec2 offset=world_position.xz-contact_position.xz;
	vec2 local=vec2(dot(offset,vec2(-contact_forward.y,contact_forward.x)),dot(offset,contact_forward));
	float shadow=(1.0-smoothstep(.62,1.18,length(local/vec2(1.06,2.23))))*.67;
	vec2 tyre=vec2(abs(local.x)-.91,abs(local.y)-1.35)/vec2(.25,.43);
	shadow=max(shadow,(1.0-smoothstep(.55,1.0,length(tyre)))*.85)*contact_strength;
	shadow*=1.0-smoothstep(.15,.65,abs(dot(world_position-contact_position,contact_normal)));
	if(rain_wetness>.01 && contact_strength>.01) {
		float beam=smoothstep(2.3,6.0,local.y)*(1.0-smoothstep(16.0,42.0,local.y))*(1.0-smoothstep(1.5,5.0,abs(local.x)));
		EMISSION+=vec3(.18,.22,.25)*beam*puddles*rain_wetness*.5;
	}
	ALBEDO*=1.0-shadow;
	EMISSION*=1.0-shadow;
	AO=1.0-shadow*.6;
	if(entry_surface && entry_shoulder>.5) {
		ALBEDO=aggregate*vec3(1.15,.87,.55);ROUGHNESS=.97;SPECULAR=.1;CLEARCOAT=0.0;EMISSION=vec3(0.0);
	}

}
