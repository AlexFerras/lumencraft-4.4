// NOTE: Shader automatically converted from Godot Engine 3.5.rc's CanvasItemMaterial.

shader_type canvas_item;
render_mode blend_mix;
uniform vec2 center=vec2(0.0,0.0);
uniform vec2 target_center=vec2(0.0,0.0);
uniform float dist=100.0;
uniform float min_dist=50.0;
uniform mat4 global_transform;

varying vec2 global_position;
void vertex()
{
	
global_position = ( vec4(VERTEX, 0.0, 1.0)).xy;

}



void fragment(){
	COLOR=texture(TEXTURE,UV+vec2(-TIME,0.0))*COLOR;
	
	float visibility= clamp((distance(global_position,target_center)-min_dist)*0.01  *clamp((dist-distance(global_position,center))*0.01,0.0,1.0),0.0,1.0);//max(max((distance(global_position,center)-1200.0)*0.05,0.0)-max((855.0-distance(global_position,center))*0.05,0.0),0.0);
	COLOR.a*=visibility;
	
	
}
