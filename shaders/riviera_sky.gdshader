shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
	float height=max(EYEDIR.y,0.0);
	vec3 blue=mix(vec3(0.63,0.84,0.87),vec3(0.055,0.32,0.66),pow(height,0.43));
	vec2 uv=EYEDIR.xz/(height+0.19)*2.1;
	float cloud=noise(uv)*0.65+noise(uv*2.1)*0.25+noise(uv*4.2)*0.10;
	float mask=smoothstep(0.59,0.76,cloud)*smoothstep(0.035,0.12,height)*(1.0-smoothstep(0.50,0.82,height));
	COLOR=mix(blue,vec3(0.94,0.96,0.95),mask*0.88);
}
