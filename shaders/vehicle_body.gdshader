shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform bool repaint_traffic = false;
uniform bool protection = false;
uniform float protection_amount = 1.0;
uniform vec4 traffic_paint = vec4(1.);
// 차체 조각 전체를 한 번에 그린다. 조각마다 다른 색·금속성·거칠기·클리어코트·발광은
// 재질 대신 정점 자료에 담는다: COLOR=색, UV=(금속성, 거칠기), UV2=(클리어코트, 발광 세기).
void fragment() {
	// 정점색은 sRGB 값이다. 기본 재질의 색 유니폼과 같게, 선형 공간에서 계산하는 렌더러에서만 변환한다.
	vec3 base = COLOR.rgb;
	if (repaint_traffic && COLOR.a < .75) base = traffic_paint.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = mix(pow((base + vec3(0.055)) / 1.055, vec3(2.4)), base / 12.92, lessThan(base, vec3(0.04045)));
	}
	ALBEDO = base;
	METALLIC = UV.x * 0.4;
	ROUGHNESS = clamp(UV.y, 0.15, 0.85);
	CLEARCOAT = UV2.x;
	CLEARCOAT_ROUGHNESS = 0.4;

	// 2D 애니메/카툰 스타일 림 라이팅 (외곽 실루엣 하이라이트)
	float NdotV = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = pow(NdotV, 3.2);
	vec3 rim_glow = vec3(0.18, 0.65, 0.95) * (rim * 0.4);
	EMISSION = base * UV2.y + rim_glow;

	if (protection) {
		ALBEDO = mix(base, vec3(.12, .55, .72), .65 * protection_amount);
		EMISSION += vec3(.03, .4, .6) * protection_amount;
	}
}

void light() {
	// 2단계 카툰 셀 셰이딩 음영 계산
	float NdotL = dot(NORMAL, LIGHT);
	float step1 = smoothstep(-0.05, 0.05, NdotL) * 0.4;
	float step2 = smoothstep(0.35, 0.45, NdotL) * 0.6;
	float toon_diffuse = step1 + step2;

	// 2D 카툰 스페큘러 (날카로운 셀 하이라이트)
	vec3 H = normalize(VIEW + LIGHT);
	float NdotH = dot(NORMAL, H);
	float toon_specular = step(0.92, NdotH) * (1.0 - ROUGHNESS);

	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * (toon_diffuse * ATTENUATION);
	SPECULAR_LIGHT += LIGHT_COLOR * (toon_specular * ATTENUATION * 1.2);
}
