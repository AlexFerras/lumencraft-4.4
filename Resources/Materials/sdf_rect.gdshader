// NOTE: Shader automatically converted from Godot Engine 3.4.beta's CanvasItemMaterial.

shader_type canvas_item;
render_mode blend_mix;
uniform vec2 rad=vec2(1.0);
uniform vec2 rad2=vec2(1.0);
uniform float mul3=1.0;
float squircle(vec2 uv,vec2 pos, float power)
{
  vec2 p = abs(pos - uv) / 0.5;
  float d = (pow(p.x,power*rad.x) + pow(p.y, power/ rad.y) );
  return 1.0 - clamp (16.0*d, 0.0, 1.0);
}

float sdRoundBox( vec2 p, vec2 b, float r )
{
  vec2 q =(abs(p) - (b)*rad2)*rad;
  return length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) -r ;
}

void fragment()
{


   float alpha= (sdRoundBox((UV-0.5)*10.0,vec2(1.0), mul3));

   COLOR=vec4(1.0,1.0,1.0,clamp(1.0-alpha,0.0,1.0));
}



