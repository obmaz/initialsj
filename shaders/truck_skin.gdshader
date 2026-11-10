shader_type spatial;
uniform sampler2D skins : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 dimensions = vec3(2.8,3.2,8.6);
uniform bool cabin = false;
uniform bool red_trailer = false;
varying vec3 point;
varying vec3 face;
void vertex() { point=VERTEX; face=NORMAL; }
void fragment() {
	bool side=abs(face.x)>.5;
	float tile=cabin ? (side ? 9.0 : 8.0) : (side ? (red_trailer ? 10.0 : 6.0) : (red_trailer ? 11.0 : 7.0));
	vec2 q=vec2(side ? point.z/dimensions.z+.5 : point.x/dimensions.x+.5,.5-point.y/dimensions.y);
	if (side && face.x>0.0) q.x=1.0-q.x;
	vec2 origin=vec2(mod(tile,4.0),floor(tile/4.0))*vec2(.25,1.0/3.0);
	vec3 image=texture(skins,origin+vec2(.0015,.002)+clamp(q,vec2(0),vec2(1))*vec2(.247,1.0/3.0-.004)).rgb;
	ALBEDO=abs(face.y)>.5 ? (cabin ? vec3(.035,.22,.43) : vec3(.68,.69,.68)) : image;
	ROUGHNESS=.68;
	METALLIC=.18;
}
