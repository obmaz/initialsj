shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ground_color : source_color = vec4(0.4,0.6,0.3,1);
uniform float grassness = 1.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 detail = texture(grain,world.xz / 7.0).rgb;
	float luma = dot(detail,vec3(0.3,0.59,0.11));
	ALBEDO = ground_color.rgb * mix(vec3(0.65 + luma * 0.7),detail * 1.7,grassness * 0.25);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
