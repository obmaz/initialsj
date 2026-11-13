// 코드와 컴파일 결과를 공유하고, 차량별 재질 유니폼만 독립적으로 바꾼다.
uniform bool toon_enabled = false;
uniform float toon_strength : hint_range(0., 1.) = .8;

float vehicle_flatness() {
	return toon_enabled ? clamp(toon_strength, 0., 1.) : 0.;
}

float vehicle_diffuse(float ndotl) {
	float strength = vehicle_flatness();
	float edge = mix(.12, .003, strength);
	float cel = .28 + .72 * smoothstep(.35 - edge, .35 + edge, ndotl);
	return mix(max(ndotl, 0.), cel, strength) / PI;
}

float vehicle_specular(float ndoth, float roughness) {
	float smooth_highlight = pow(max(ndoth, 0.), exp2(3. + (1. - roughness) * 7.));
	float cel_highlight = step(.96, ndoth) * .15;
	return mix(smooth_highlight, cel_highlight, vehicle_flatness()) * (1. - roughness);
}
