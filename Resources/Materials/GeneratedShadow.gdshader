
shader_type canvas_item;
render_mode blend_mix;
uniform vec2 im_size;
uniform float shadow_size = 1.0;
uniform float shadow_param_1 = 1.0;
uniform float shadow_param_2 = 1.0;
uniform float shadow_param_3 = 1.0;

//uniform mat4 global_transform;
//varying vec2 global_position;
varying vec2 step_size;
varying float decay_1;
varying float decay_2;
varying float decay_3;

void vertex() {
//	global_position = (global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
	step_size = 1.0/im_size * shadow_size ;
	decay_1 = 0.2969069646728344/shadow_param_1;
	decay_2 = 0.09447039785044732/shadow_param_2;
	decay_3 = 0.010381362401148057/shadow_param_3;
}

void fragment() {
	vec4 color = texture( TEXTURE, UV ) ;
	color.rgb = vec3(0.0);
	if (color.a > 0.0) {
		color.a = 1.0;
	} else {

		color.a += textureLod( TEXTURE, UV+vec2(1.99307958478,0.0)*step_size , 1.0).a * decay_1;
		color.a += textureLod( TEXTURE, UV+vec2(0.0,1.99307958478)*step_size , 1.0).a * decay_1;
		color.a += textureLod( TEXTURE, UV-vec2(1.99307958478,0.0)*step_size , 1.0).a * decay_1;
		color.a += textureLod( TEXTURE, UV-vec2(0.0,1.99307958478)*step_size , 1.0).a * decay_1;

		color.a += texture( TEXTURE, UV+vec2(1.68034 ,1.68034 )*step_size ).a * decay_1;
		color.a += texture( TEXTURE, UV-vec2(1.68034 ,1.68034 )*step_size ).a * decay_1;
		color.a += texture( TEXTURE, UV+vec2(-1.68034 ,1.68034 )*step_size ).a * decay_1;
		color.a += texture( TEXTURE, UV-vec2(-1.68034 ,1.68034 )*step_size ).a * decay_1;

		color.a += texture( TEXTURE, UV+vec2(3.99308,0.0)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV+vec2(0.0,3.99308)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV-vec2(3.99308,0.0)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV-vec2(0.0,3.99308)*step_size ).a * decay_2;

		color.a += texture( TEXTURE, UV+vec2(3.36068,3.36068)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV-vec2(3.36068,3.36068)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV+vec2(-3.36068,3.36068)*step_size ).a * decay_2;
		color.a += texture( TEXTURE, UV-vec2(-3.36068,3.36068)*step_size ).a * decay_2;

		color.a += texture( TEXTURE, UV+vec2(5.98962,0.0)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV+vec2(0.0,5.98962)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV-vec2(5.98962,0.0)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV-vec2(0.0,5.98962)*step_size ).a * decay_3;

		color.a += texture( TEXTURE, UV+vec2(5.04102,5.04102)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV-vec2(5.04102,5.04102)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV+vec2(-5.04102,5.04102)*step_size ).a * decay_3;
		color.a += texture( TEXTURE, UV-vec2(-5.04102,5.04102)*step_size ).a * decay_3;
//	5.176470588235294
	}
	COLOR = color;
}
