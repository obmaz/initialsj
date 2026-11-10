shader_type spatial;
uniform sampler2D skins : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int brand = 0;
varying vec3 face;
varying vec3 point;
void vertex() { face=NORMAL; point=VERTEX; }
void fragment() {
	bool end=abs(face.x)>.5;
	vec2 q=vec2(end ? point.z/2.6+.5 : point.x/12.0+.5,.5-point.y/2.45);
	// 야적장 모델은 긴 축이 X이므로 X면이 문, Z면이 긴 측면이다.
	vec2 uv=vec2(float(brand)*.25,.5*(end ? 1.0 : 0.0))+vec2(.0015,.003)+q*vec2(.247,.494);
	vec3 surface=texture(skins,uv).rgb;
	ALBEDO=surface;
	ROUGHNESS=.84;METALLIC=.2;
}
