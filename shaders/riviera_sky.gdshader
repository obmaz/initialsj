shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
void sky() {
	vec3 direction=normalize(EYEDIR);
	// 실제 위경도로 읽어 정면 사진을 수평으로 늘리는 왜곡을 없앤다.
	vec2 uv=vec2(atan(direction.x,direction.z)/(2.0*PI)+.5,acos(clamp(direction.y,-1.0,1.0))/PI);
	vec3 front=texture(panorama,uv).rgb;
	// 파노라마 양 끝의 작은 색차만 좁은 경계에서 혼합한다.
	float edge=abs(uv.x-.5)*2.0;
	vec3 opposite=texture(panorama,vec2(1.0-uv.x,uv.y)).rgb;
	COLOR=mix(front,opposite,smoothstep(.975,1.0,edge)*.5);
}
