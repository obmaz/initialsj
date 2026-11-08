shader_type sky;
// A clear night: deep blue gradient, a warm city glow at the horizon, stars and a pale moon.
uniform vec3 top_color : source_color = vec3(0.012, 0.03, 0.09);
uniform vec3 horizon_color : source_color = vec3(0.07, 0.12, 0.24);
uniform vec3 glow_color : source_color = vec3(0.45, 0.28, 0.18);
uniform vec3 moon_direction = vec3(-0.35, 0.55, -0.75);
uniform float star_density = 0.004;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = clamp(dir.y, 0.0, 1.0);
	vec3 color = mix(horizon_color, top_color, pow(height, 0.45));
	color += glow_color * pow(1.0 - height, 7.0) * 0.55;
	if (dir.y < 0.0) {
		color = mix(horizon_color * 0.45, vec3(0.01, 0.015, 0.03), clamp(-dir.y * 3.0, 0.0, 1.0));
	} else {
		vec3 cell = floor(dir * 480.0);
		float star = step(1.0 - star_density, hash(cell));
		float twinkle = 0.65 + 0.35 * hash(cell + vec3(7.0));
		color += vec3(0.9, 0.95, 1.0) * star * twinkle * smoothstep(0.02, 0.35, height);
	}
	vec3 moon = normalize(moon_direction);
	float disc = smoothstep(0.9988, 0.9993, dot(dir, moon));
	float halo = pow(max(dot(dir, moon), 0.0), 220.0) * 0.35;
	color += vec3(0.85, 0.9, 1.0) * disc + vec3(0.35, 0.45, 0.7) * halo;
	COLOR = color;
}
