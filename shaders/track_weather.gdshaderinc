// 코스별 원경 위에 공용 시간대·강수와 서로 다른 달의 위상을 합성한다.
uniform int environment_period = 0;
uniform float rain_amount = 0.0;
uniform int environment_course = 0;
uniform vec3 celestial_direction = vec3(.545,.469,-.698);
uniform float moon_phase = 2.25;
uniform float moon_roll = -.25;
uniform sampler2D moon_surface : source_color, filter_linear_mipmap, repeat_disable;

float tw_hash(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float tw_noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(tw_hash(i),tw_hash(i+vec2(1,0)),f.x),mix(tw_hash(i+vec2(0,1)),tw_hash(i+vec2(1)),f.x),f.y);
}
vec4 tw_moon(vec3 eye) {
	vec3 right=normalize(cross(vec3(0,1,0),celestial_direction));
	vec3 up=cross(celestial_direction,right);
	vec2 p=vec2(dot(eye,right),dot(eye,up))/.027;
	p=mat2(vec2(cos(moon_roll),sin(moon_roll)),vec2(-sin(moon_roll),cos(moon_roll)))*p;
	float r=dot(p,p);
	if(r>1.0 || dot(eye,celestial_direction)<.9) return vec4(0);
	vec3 n=vec3(p,sqrt(max(0.0,1.0-r)));
	float lit=smoothstep(-.02,.06,dot(n,vec3(sin(moon_phase),0,cos(moon_phase))));
	vec3 rock=texture(moon_surface,vec2(.5)+p*.44).rgb;
	return vec4(rock*(.018+lit*.94),1.0-smoothstep(.95,1.0,r));
}
vec3 track_weather_sky(vec3 original,vec3 eye,float azimuth) {
	if(environment_period==0 && rain_amount<.01 && environment_course!=4) return original;
	bool night=environment_period==2;
	vec3 tint=night?vec3(.035,.055,.10):(environment_period==1?vec3(.75,.45,.35):vec3(.85,.9,.96));
	vec3 landscape=original*tint;
	float sky_mask=smoothstep(.025,.19,original.b-original.r)*smoothstep(0.0,.13,original.b-original.g);
	sky_mask=mix(sky_mask,1.0,smoothstep(.26,.6,eye.y))*smoothstep(.0,.11,eye.y);
	if(environment_course==4) {
		// 기존 협곡 원경에 그려진 낮은 태양이 밤에도 남지 않게 한다.
		float u=.65*6.283185-3.141593;
		vec3 baked_sun=vec3(sin(u)*.9995,.0314,cos(u)*.9995);
		sky_mask=max(sky_mask,smoothstep(.992,.999,dot(eye,baked_sun)));
		float warm_sky=smoothstep(.18,.48,original.r)*smoothstep(.12,.32,original.g)*smoothstep(.06,.18,eye.y);
		sky_mask=max(sky_mask,warm_sky);
	}
	vec3 top=night?vec3(.003,.008,.024):(environment_period==1?vec3(.045,.08,.2):vec3(.15,.36,.63));
	vec3 horizon=night?vec3(.035,.055,.105):(environment_period==1?vec3(.81,.30,.13):vec3(.60,.76,.84));
	vec3 color=mix(horizon,top,smoothstep(0.0,.47,max(0.0,eye.y)));
	if(night) {
		vec3 atmospheric_color=color;
		vec2 angular=vec2(azimuth,asin(clamp(eye.y,-1.0,1.0)))*850.0;
		vec2 cell=floor(angular);
		float stellar_density=environment_course==4?.9978:.9994;
		float star_seed=tw_hash(cell);
		vec3 star_color=mix(vec3(.38,.49,.68),vec3(.78,.68,.48),tw_hash(cell+13.0));
		float star_core=exp(-dot(fract(angular)-vec2(.5),fract(angular)-vec2(.5))*16.0);
		color+=star_color*star_core*step(stellar_density,star_seed)*smoothstep(.08,.4,eye.y);
		if(environment_course==4) {
			// 도로 조명이 없는 협곡의 정적인 별 하늘·은하수. 달리는 동안 패턴을 재생성하지 않는다.
			float band=exp(-pow(dot(eye,normalize(vec3(.53,-.39,.75)))/.12,2.0));
			float dust=tw_noise(eye.xz*28.0)+tw_noise(eye.xy*53.0)*.4;
			color+=vec3(.022,.024,.039)*band*mix(.25,1.0,dust)*smoothstep(.03,.3,eye.y);
		}
		vec4 moon=tw_moon(eye);
		color=mix(color,atmospheric_color+moon.rgb,moon.a);
	} else if(environment_period==1 || environment_course==4) {
		float sun=smoothstep(.9996,.99985,dot(eye,celestial_direction));
		color+=vec3(1.0,.62,.25)*sun*(1.0-rain_amount);
	}
	if(rain_amount>.01) {
		vec2 p=eye.xz/(max(eye.y,.05)+.2)*2.0;
		float cloud=.62*tw_noise(p)+.28*tw_noise(p*2.03+vec2(3.1,4.7))+.1*tw_noise(p*4.01);
		vec3 storm=mix(night?vec3(.012,.02,.035):vec3(.17,.21,.25),night?vec3(.05,.07,.105):vec3(.45,.51,.56),cloud);
		color=mix(color,storm,rain_amount);
	}
	return mix(landscape,color,sky_mask);
}
