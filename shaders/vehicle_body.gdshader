shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/vehicle_shading.gdshaderinc"
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
	METALLIC = UV.x * (1. - vehicle_flatness());
	ROUGHNESS = mix(clamp(UV.y, .15, .85), .95, vehicle_flatness());
	CLEARCOAT = UV2.x * (1. - vehicle_flatness());
	CLEARCOAT_ROUGHNESS = 0.4;

	EMISSION = base * UV2.y;

	if (protection) {
		ALBEDO = mix(base, vec3(.12, .55, .72), .65 * protection_amount);
		EMISSION += vec3(.03, .4, .6) * protection_amount;
	}
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float ndoth = max(dot(NORMAL, normalize(VIEW + LIGHT)), 0.);
	DIFFUSE_LIGHT += LIGHT_COLOR * vehicle_diffuse(ndotl) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * vehicle_specular(ndoth, ROUGHNESS) * ATTENUATION;
}
