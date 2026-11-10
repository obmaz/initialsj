shader_type sky;
uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform sampler2D cloud_panorama : source_color, filter_linear, repeat_enable;
uniform bool goal_enabled = false;
uniform float horizon_lift = 0.055;
uniform float heading = 0.0;
uniform float cloudiness = 0.0;
uniform vec4 sky_tint : source_color = vec4(1.0);
void sky() {
 vec3 d=normalize(EYEDIR);
 float u=fract((atan(d.x,d.z)-heading)/(2.0*PI)+.5);
 vec2 uv=vec2(u,acos(clamp(d.y,-1.0,1.0))/PI);
 uv.y=clamp(0.5+(uv.y-0.5)*(goal_enabled ? 1.65 : 1.0)+(goal_enabled ? horizon_lift : 0.0),.001,.999);
 vec3 front=goal_enabled ? texture(panorama,uv).rgb : texture(cloud_panorama,uv).rgb;
 vec3 seam=goal_enabled ? texture(panorama,vec2(1.0-u,uv.y)).rgb : texture(cloud_panorama,vec2(1.0-u,uv.y)).rgb;
 COLOR=mix(front,seam,smoothstep(.975,1.0,abs(u-.5)*2.0)*.5);
 COLOR=mix(COLOR,vec3(dot(COLOR,vec3(.2126,.7152,.0722)))*vec3(.55,.65,.74),cloudiness*.75);
 COLOR *= sky_tint.rgb;
}
