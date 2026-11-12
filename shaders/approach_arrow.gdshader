shader_type spatial;
// 노면 안내는 역광·반전 배치에서도 읽히도록 조명에 의한 색 감쇠를 받지 않는다.
render_mode cull_disabled, unshaded;
uniform bool night = false;
void fragment() {
	ALBEDO = vec3(.94, .79, .30);
	EMISSION = night ? vec3(.16, .12, .025) : vec3(0.0);
}
