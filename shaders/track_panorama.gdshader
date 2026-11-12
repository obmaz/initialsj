shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
#include "res://shaders/track_weather.gdshaderinc"
uniform float horizon_offset = 0.0;
void sky() {
	vec3 direction=normalize(EYEDIR);
	// 실제 위경도로 읽어 정면 사진을 수평으로 늘리는 왜곡을 없앤다.
	vec2 uv=vec2(atan(direction.x,direction.z)/(2.0*PI)+.5,acos(clamp(direction.y,-1.0,1.0))/PI);
	uv.y=clamp(uv.y+horizon_offset,.001,.999);
	// atan의 ±PI 경계에서 암시적 미분이 거대한 mip 단계로 튀지 않게 한다.
	// 주행 화면에서는 각도당 원본 해상도보다 확대되므로 기본 레벨을 읽는다.
	vec3 front=textureLod(panorama,uv,0.0).rgb;
	// 파노라마 양 끝의 작은 색차만 좁은 경계에서 혼합한다.
	float edge=abs(uv.x-.5)*2.0;
	vec3 opposite=textureLod(panorama,vec2(1.0-uv.x,uv.y),0.0).rgb;
	COLOR=mix(front,opposite,smoothstep(.975,1.0,edge)*.5);
	COLOR=track_weather_sky(COLOR,direction,atan(direction.x,direction.z));
}
