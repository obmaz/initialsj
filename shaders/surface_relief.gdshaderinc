// 이미 읽은 표면 밝기의 미분으로 미세 법선을 구한다. 추가 텍스처 샘플·삼면 투영은 없다.
// 원근이 눕거나 지오메트리가 축소된 경우에도 경사가 무한히 커지지 않게 제한한다.
vec3 relief_normal(float height, vec3 position, vec3 normal, float strength) {
	vec3 dx=dFdx(position),dy=dFdy(position);
	vec3 a=cross(dy,normal),b=cross(normal,dx);
	float det=dot(dx,a);
	vec3 slope=sign(det)*(dFdx(height)*a+dFdy(height)*b)/max(abs(det),.000001);
	slope/=1.0+length(slope)*1.5;
	return normalize(normal-slope*strength);
}
