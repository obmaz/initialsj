shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : hint_screen_texture, filter_linear;
uniform float storm_flash = 0.0;
uniform bool high_quality = true;
uniform float lens_amount = 0.0;
uniform float lens_clock = 0.0;

float drop_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec4 rain_drop(vec2 uv, float scale, float seed, vec2 aspect) {
	vec2 grid=uv*aspect*scale;
	vec2 cell=floor(grid);
	float random=drop_hash(cell+seed);
	float age=fract(lens_clock*.16+random);
	vec2 center=vec2(.2+.6*random,.2+.6*drop_hash(cell+17.0+seed));
	vec2 drift=(uv-vec2(.5,.42))*age*age*.34;
	vec2 p=fract(grid)-center-drift;
	p.y*=1.0+age*.6;
	float radius=mix(.09,.23,drop_hash(cell+31.0));
	float r=length(p)/radius;
	r*=1.0+.055*sin(atan(p.y,p.x)*3.0+random*6.28);
	float fade=smoothstep(0.0,.08,age)*(1.0-smoothstep(.65,1.0,age));
	float edge_zone=smoothstep(.14,.36,length((uv-vec2(.5,.52))*vec2(1.0,1.25)));
	float mask=(1.0-smoothstep(.72,1.0,r))*fade*edge_zone*step(.4,random)*lens_amount;
	vec2 q=p/radius;
	float rim=exp(-dot(q-vec2(-.28,-.61),q-vec2(-.28,-.61))*22.0)*mask;
	float lens=sqrt(max(0.0,1.0-r*r));
	return vec4(q*(.013-.006*lens)*mask, rim, mask);
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 drop=vec4(0.0);
	if(lens_amount>.01) {
		vec2 aspect=vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.0);
		drop=rain_drop(uv,7.0,0.0,aspect);
		if(high_quality) drop+=rain_drop(uv,11.0,23.0,aspect)*.65;
		uv=clamp(uv+drop.xy,vec2(.002),vec2(.998));
	}
	COLOR = texture(scene, uv);
	// 반투명 굴절과 얇은 가장자리 반사만 더한다. HUD는 이 패스 뒤에서 그린다.
	COLOR.rgb=COLOR.rgb*(1.0-drop.w*.07)+vec3(.62,.76,.85)*drop.z*.30;
	COLOR.rgb=mix(COLOR.rgb,vec3(.65,.77,1.0),storm_flash*.22*(1.0-smoothstep(.25,.72,SCREEN_UV.y)));

}
