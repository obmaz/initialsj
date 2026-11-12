shader_type spatial;
render_mode cull_disabled;

uniform sampler2D heritage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying flat float surface_kind;

void vertex() {
	surface_kind = UV2.x;
}

void fragment() {
	vec2 origin = vec2(0.0);
	vec2 span = vec2(0.5, 1.0);
	if (surface_kind > 0.5) {
		origin = vec2(0.5, surface_kind > 1.5 ? 0.5 : 0.0);
		span = vec2(0.5);
	}
	// 경계 여백과 연속 UV 미분으로 반복 이음새의 다른 아틀라스 재질 유입을 막는다.
	vec2 inset = vec2(0.004);
	vec2 atlas_uv = origin + inset + fract(UV) * (span - inset * 2.0);
	ALBEDO = textureGrad(heritage_atlas, atlas_uv, dFdx(UV) * span, dFdy(UV) * span).rgb;
	ROUGHNESS = surface_kind < 0.5 ? 0.94 : (surface_kind < 1.5 ? 0.66 : 0.8);
}
