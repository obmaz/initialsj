shader_type spatial;
uniform sampler2D skins : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec2 panel;
void vertex(){panel=UV2;}
void fragment(){
	if(panel.x>.5){
		float row=round(panel.y)-1.0;
		float y0=row<.5 ? .008 : (row<1.5 ? .325 : .693);
		float y1=row<.5 ? .298 : (row<1.5 ? .661 : .991);
		vec2 at=vec2((round(panel.x)-1.0+mix(.012,.988,UV.x))/3.0,mix(y0,y1,UV.y));
		ALBEDO=texture(skins,at).rgb;
		ROUGHNESS=.78;METALLIC=.22;
	}else{ALBEDO=COLOR.rgb;ROUGHNESS=.8;METALLIC=.3;}
}
