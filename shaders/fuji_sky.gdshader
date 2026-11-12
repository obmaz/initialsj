shader_type sky;

// Three panels around the full horizon, each drawn at the same pixel scale:
// the generated panorama covers the 120 degrees around Mount Fuji; two baked
// rear panels (tools/bake_fuji_backdrop.py) cover the remaining 240 degrees.
// The textures are only ever magnified on screen, so plain linear filtering is
// used and no mip level can mark the joins between panels.
uniform sampler2D panorama : source_color, filter_linear, repeat_disable;
uniform sampler2D back_a : source_color, filter_linear, repeat_disable;
uniform sampler2D back_b : source_color, filter_linear, repeat_disable;
uniform float center_yaw = 2.007129;
uniform float horizontal_span = 2.094395;
uniform float vertical_span = 1.047198;
uniform float horizon_uv = 0.51;

// 시간대·강수는 트랙1의 활성 프리셋만 전달한다. 기본값은 기존 맑은 낮과 같다.
uniform int environment_period = 0;
uniform float rain_amount = 0.0;

float cloud_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(cell), cloud_hash(cell + vec2(1.0,0.0)), f.x),
		mix(cloud_hash(cell + vec2(0.0,1.0)), cloud_hash(cell + vec2(1.0)), f.x), f.y);
}

vec3 environment_sky(vec3 original, vec3 eye, float azimuth) {
	if (environment_period == 0 && rain_amount < 0.01) { return original; }
	bool night = environment_period == 2;
	vec3 tint = night ? vec3(.055, .09, .18) : (environment_period == 1 ? vec3(.78,.47,.36) : vec3(.65,.72,.76));
	vec3 landscape = original * tint;
	float sky_mask = smoothstep(.025,.19,original.b-original.r) * smoothstep(.0,.13,original.b-original.g);
	sky_mask = mix(sky_mask, 1.0, smoothstep(.45,.75,eye.y)) * smoothstep(.0,.14,eye.y);
	float altitude = clamp(eye.y,0.0,1.0);
	vec3 top = night ? vec3(.005,.012,.034) : (environment_period == 1 ? vec3(.055,.10,.24) : vec3(.18,.24,.29));
	vec3 horizon = night ? vec3(.055,.085,.15) : (environment_period == 1 ? vec3(.85,.33,.14) : vec3(.49,.57,.62));
	vec3 sky_color = mix(horizon,top,smoothstep(0.0,.42,altitude));
	vec3 body_direction = night ? normalize(vec3(.545,.469,-.698)) : normalize(vec3(.612,.104,-.783));
	float body = smoothstep(.9995,.9998,dot(eye,body_direction));
	if (environment_period != 0) {
		sky_color += body * (night ? vec3(.75,.82,.92) : vec3(1.0,.66,.3)) * (1.0-rain_amount);
	}
	if (night) {
		vec2 cell = floor(vec2(azimuth,asin(clamp(eye.y,-1.0,1.0))) * 850.0);
		float star = fract(sin(dot(cell,vec2(127.1,311.7))) * 43758.5453);
		sky_color += vec3(.45,.55,.7) * step(.9994,star) * smoothstep(.15,.5,eye.y) * (1.0-rain_amount);
	}
	// 구름은 월드 방향에 고정한 정적 보간 노이즈이다. TIME·방사휘도 반복 갱신은 사용하지 않는다.
	if (rain_amount > .01) {
		vec2 p = eye.xz / (max(eye.y,.05) + .2) * 2.0;
		float cloud = .62*cloud_noise(p) + .28*cloud_noise(p*2.03+vec2(3.1,4.7)) + .1*cloud_noise(p*4.01);
		vec3 rain_cloud = mix(night ? vec3(.016,.025,.045) : vec3(.19,.24,.28), night ? vec3(.065,.085,.12) : vec3(.48,.54,.58), cloud);
		sky_color = mix(sky_color,rain_cloud,rain_amount);
	}
	return mix(landscape,sky_color,sky_mask);
}

void sky() {
	float azimuth = atan(EYEDIR.x, EYEDIR.z);
	float relative = atan(sin(azimuth - center_yaw), cos(azimuth - center_yaw));
	float v = clamp(horizon_uv - asin(clamp(EYEDIR.y, -1.0, 1.0)) / vertical_span, 0.0, 1.0);
	float half_span = horizontal_span * 0.5;
	if (abs(relative) <= half_span) {
		COLOR = texture(panorama, vec2(0.5 + relative / horizontal_span, v)).rgb;
	} else {
		// The rear strip runs left to right from the panorama's right edge,
		// round the back, to its left edge.
		float around = relative > 0.0 ? relative - half_span : relative + 6.283185 - half_span;
		float b = around / (6.283185 - horizontal_span);
		COLOR = b < 0.5 ? texture(back_a, vec2(b * 2.0, v)).rgb : texture(back_b, vec2(b * 2.0 - 1.0, v)).rgb;
	}
	COLOR = environment_sky(COLOR, EYEDIR, azimuth);
}
