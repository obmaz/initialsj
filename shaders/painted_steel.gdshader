shader_type spatial;
uniform vec4 paint_color : source_color = vec4(.32,.07,.045,1.0);
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float weather=sin(world.y*.21+sin(world.x*.38)+sin(world.z*.31))*.5+.5;
 ALBEDO=paint_color.rgb*mix(.86,1.04,weather);
 METALLIC=.35;ROUGHNESS=.52+weather*.13;SPECULAR=.4;
}
