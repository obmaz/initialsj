shader_type spatial;
uniform float night_lighting = 0.0;
void fragment() {
	ALBEDO=COLOR.rgb;
	ROUGHNESS=COLOR.a>.5?.3:.65;
	METALLIC=COLOR.a>.5?0.0:.35;
	EMISSION=COLOR.a>.5?vec3(1.0,.84,.55)*night_lighting*3.0:vec3(0);
}
