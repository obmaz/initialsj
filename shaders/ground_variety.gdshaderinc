// 생성형 원본의 서로 다른 결을 월드 좌표에서 연속 혼합한다. 타일 경계와 거울 반복을 숨긴다.
float gv_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float gv_noise(vec2 p) {
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(gv_hash(i),gv_hash(i+vec2(1,0)),f.x),mix(gv_hash(i+vec2(0,1)),gv_hash(i+vec2(1)),f.x),f.y);
}
vec2 gv_turn(vec2 p,float index) {
	if(index<.5) return p;
	if(index<1.5) return vec2(-p.y,p.x);
	if(index<2.5) return -p;
	return vec2(p.y,-p.x);
}
vec3 gv_tile(sampler2D source,vec2 p,vec2 tile,vec2 cells,vec2 dx,vec2 dy) {
	vec2 margin=vec2(1.5)/vec2(textureSize(source,0));
	vec2 uv=tile/cells+margin+fract(p)*(1.0/cells-2.0*margin);
	return textureGrad(source,uv,dx/cells,dy/cells).rgb;
}
vec3 gv_seamless(sampler2D source,vec2 p,vec2 tile,vec2 cells,vec2 dx,vec2 dy) {
	vec2 a=sin(fract(p)*3.14159265),b=sin(fract(p+.5)*3.14159265);
	float wa=a.x*a.x*a.y*a.y+.001,wb=b.x*b.x*b.y*b.y+.001;
	return (gv_tile(source,p,tile,cells,dx,dy)*wa+gv_tile(source,p+.5,tile,cells,dx,dy)*wb)/(wa+wb);
}
vec3 gv_surface(sampler2D source,vec2 world,float metres,vec2 cells,vec2 offset) {
	float habitat=gv_noise(world*.027+vec2(31,7))*2.1+gv_noise(world*.071+vec2(9,43))*.89;
	float first=floor(habitat),second=mod(first+1.0,4.0);
	vec2 a=vec2(mod(first,2.0),floor(first*.5))+offset;
	vec2 b=vec2(mod(second,2.0),floor(second*.5))+offset;
	vec2 p=world/metres;
	vec2 dx=dFdx(p),dy=dFdy(p);
	vec3 material_a=gv_seamless(source,gv_turn(p,first)+vec2(.217+first*.173,.39+first*.311),a,cells,gv_turn(dx,first),gv_turn(dy,first));
	vec3 material_b=gv_seamless(source,gv_turn(p,second)+vec2(.217+second*.173,.39+second*.311),b,cells,gv_turn(dx,second),gv_turn(dy,second));
	return mix(material_a,material_b,smoothstep(.1,.9,fract(habitat)))*mix(.94,1.05,gv_noise(world*.008));
}
