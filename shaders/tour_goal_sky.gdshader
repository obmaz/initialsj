shader_type sky;
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform float heading = 0.0;
uniform float cloudiness = 0.0;
void sky() {
 vec3 d=normalize(EYEDIR);
 float u=fract((atan(d.x,d.z)-heading)/(2.0*PI)+.5);
 vec2 uv=vec2(u,acos(clamp(d.y,-1.0,1.0))/PI);
 vec3 front=texture(panorama,uv).rgb;
 vec3 seam=texture(panorama,vec2(1.0-u,uv.y)).rgb;
 COLOR=mix(front,seam,smoothstep(.975,1.0,abs(u-.5)*2.0)*.5);
 COLOR=mix(COLOR,vec3(dot(COLOR,vec3(.2126,.7152,.0722)))*vec3(.55,.65,.74),cloudiness*.75);
}
