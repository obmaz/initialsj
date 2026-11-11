shader_type spatial;
uniform bool repaint_traffic = false;
uniform vec4 traffic_paint = vec4(1.);
// 차체 조각 전체를 한 번에 그린다. 조각마다 다른 색·금속성·거칠기·클리어코트·발광은
// 재질 대신 정점 자료에 담는다: COLOR=색, UV=(금속성, 거칠기), UV2=(클리어코트, 발광 세기).
void fragment() {
	// 정점색은 sRGB 값이다. 기본 재질의 색 유니폼과 같게, 선형 공간에서 계산하는 렌더러에서만 변환한다.
	vec3 base = COLOR.rgb;
	if(repaint_traffic && COLOR.a<.75) base=traffic_paint.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = mix(pow((base+vec3(0.055))/1.055,vec3(2.4)),base/12.92,lessThan(base,vec3(0.04045)));
	}
	ALBEDO = base;
	METALLIC = UV.x;
	ROUGHNESS = UV.y;
	CLEARCOAT = UV2.x;
	CLEARCOAT_ROUGHNESS = 0.5;
	EMISSION = base*UV2.y;
}
