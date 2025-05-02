shader_type canvas_item;    
uniform sampler2D texture1;
uniform sampler2D texture2;
uniform sampler2D texture3;
uniform sampler2D texture4;
uniform float resolution1 = 16;
uniform float resolution2 = 16;
uniform float resolution3 = 16;
uniform float resolution4 = 16;

uniform float multiply1 = 1.0;
uniform float multiply2 = 1.0;
uniform float multiply3 = 1.0;
uniform float multiply4 = 1.0;

uniform float wavy1 = 0.0;
uniform float wavy2 = 0.0;
uniform float wavy3 = 0.0;
uniform float wavy4 = 0.0;

uniform float hsvoffset1=0.0;
uniform float hsvsaturation1=0.0;
uniform float hsvlight1=0.0;

uniform float hsvoffset2=0.0;
uniform float hsvsaturation2=0.0;
uniform float hsvlight2=0.0;

uniform float hsvoffset3=0.0;
uniform float hsvsaturation3=0.0;
uniform float hsvlight3=0.0;

uniform float hsvoffset4=0.0;
uniform float hsvsaturation4=0.0;
uniform float hsvlight4=0.0;

uniform bool black_as_empty=false;


// All components are in the range [0…1], including hue.
vec4 rgb2hsv(vec4 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x,c.a);
}
 

// All components are in the range [0…1], including hue.
vec4 hsv2rgb(vec4 c,float hsvoffset,float hsvsaturation,float hsvlight)
{
	c.r+=hsvoffset;
	c.g+=hsvsaturation;
	c.b+=hsvlight;
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return vec4(c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y),c.a);
}



void fragment () {

	float time_scale=1.0;

	
	vec2 uv_waved=vec2(sin(TIME*time_scale+UV.x*1000.0),cos(TIME*time_scale+UV.y*990.0))*0.00005;
	vec4 ster=texture(TEXTURE,UV);
	ster.w*=float(!black_as_empty);
	vec4 tex4= hsv2rgb(rgb2hsv(texture(texture4,(wavy4>0.0?UV+uv_waved*wavy4:UV)*resolution4)),hsvoffset4,hsvsaturation4,hsvlight4)*vec4(vec3(multiply4),ster.w)*float(!black_as_empty);
	float maxa = 1.0-tex4.a;
	vec4 tex3= hsv2rgb(rgb2hsv(texture(texture3,(wavy3>0.0?UV+uv_waved*wavy3:UV)*resolution3)),hsvoffset3,hsvsaturation3,hsvlight3)*vec4(vec3(multiply3), min(maxa, ster.z));
	maxa -= tex3.a;
	vec4 tex2= hsv2rgb(rgb2hsv(texture(texture2,(wavy2>0.0?UV+uv_waved*wavy2:UV)*resolution2)),hsvoffset2,hsvsaturation2,hsvlight2)*vec4(vec3(multiply2), min(maxa, ster.y));
	maxa -= tex2.a;
	vec4 tex1= hsv2rgb(rgb2hsv(texture(texture1,(wavy1>0.0?UV+uv_waved*wavy1:UV)*resolution1)),hsvoffset1,hsvsaturation1,hsvlight1)*vec4(vec3(multiply1), min(maxa, ster.x));
	


	///max(ster.x+ster.y+ster.z+ster.w,1.0)
	tex1.rgb *= tex1.a;
	tex2.rgb *= tex2.a;
	tex3.rgb *= tex3.a;
	tex4.rgb *= tex4.a;
	COLOR= tex1+tex2+tex3+tex4;

}