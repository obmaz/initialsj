shader_type spatial;
render_mode diffuse_toon, specular_toon;
uniform vec4 base_paint : source_color = vec4(1.);
uniform vec4 secondary_paint : source_color = vec4(.1, .7, .8, 1.);
uniform sampler2D livery_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int livery = 0;
uniform int vehicle_column = 0;
uniform float finish_roughness = .25;
uniform float finish_metallic = .6;
uniform bool use_source_texture = false;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform bool protection = false;
uniform float protection_amount = 1.0;

void fragment() {
	vec3 base = base_paint.rgb;
	vec3 source = vec3(0.);
	if (use_source_texture) source = texture(source_texture, UV).rgb;
	float paint_mask = use_source_texture ? smoothstep(.025, .16, source.r - max(source.g, source.b)) : 1.;
	if (use_source_texture) base = mix(source, base * clamp(source.r * 1.5, .35, 1.), paint_mask);
	if (livery > 0) {
		vec2 cell = (vec2(float(vehicle_column % 4), float(livery - 1)) + mix(vec2(.015), vec2(.985), use_source_texture ? UV2 : UV)) / vec2(4., 3.);
		vec3 graphic = texture(livery_atlas, cell).rgb;
		float mask = smoothstep(.025, .18, max(graphic.r, max(graphic.g, graphic.b)));
		base = mix(base, mix(graphic, secondary_paint.rgb, .15), mask * paint_mask);
	}
	ALBEDO = base;
	METALLIC = mix(.1, finish_metallic * 0.5, paint_mask);
	ROUGHNESS = mix(.55, finish_roughness, paint_mask);
	CLEARCOAT = finish_roughness < .5 ? .85 : .05;
	CLEARCOAT_ROUGHNESS = .2;

	// 2D 애니메/카툰 스타일 림 라이팅
	float NdotV = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float rim = pow(NdotV, 3.2);
	vec3 rim_glow = vec3(0.18, 0.65, 0.95) * (rim * 0.4);
	EMISSION = rim_glow;

	if (protection) {
		ALBEDO = mix(base, vec3(.12, .55, .72), .65 * protection_amount);
		EMISSION += vec3(.03, .4, .6) * protection_amount;
	}
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float step1 = smoothstep(-0.05, 0.05, NdotL) * 0.4;
	float step2 = smoothstep(0.35, 0.45, NdotL) * 0.6;
	float toon_diffuse = step1 + step2;

	vec3 H = normalize(VIEW + LIGHT);
	float NdotH = dot(NORMAL, H);
	float toon_specular = step(0.92, NdotH) * (1.0 - ROUGHNESS);

	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * (toon_diffuse * ATTENUATION);
	SPECULAR_LIGHT += LIGHT_COLOR * (toon_specular * ATTENUATION * 1.2);
}
