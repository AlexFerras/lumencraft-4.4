shader_type canvas_item;
render_mode blend_mul;
uniform mat4 global_transform;
//uniform vec2 camera_zoom;
uniform sampler2D darkness;
uniform sampler2D map_texture;
uniform float light_exponent = 1.0;
uniform float light_amplify = 1.0;

varying vec2 global_position;



const float material_shadow[32] = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 
									1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
									1.0, 1.0, 1.0, 1.0, 1.0, 0.0/* 25 empty*/, 1.0, 0.0, 1.0, 0.0, 
									0.0,0.0};



void vertex() {
	global_position=(global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
}



void fragment()
{
	vec4 col = texture(darkness,UV);
	
	
	
	vec2 map_inverse_size=1.0/vec2(textureSize(map_texture,0));
//	vec4 real_col = textureLod(map_texture, (global_position)*map_inverse_size,0.0);
	vec4 real_col=texelFetch(map_texture, ivec2(global_position),0);
	vec4 smp_lod = textureLod(map_texture, (global_position)*map_inverse_size,1.5);

	//COLOR=col;
	
	float material_difference=(real_col.g-smp_lod.g);
	float unshaded_faloff=pow(smp_lod.a,10);

	float is_unshaded= 1.0-material_shadow[int(round(real_col.g*255.0))];

	
	float light_power = clamp(pow((col.r+col.g+col.b)*0.33333*light_amplify,light_exponent),0.0,5.0); //kontrola max swiatla
	//float over_saturated=when_gt(light_power,1.0);
	float over_saturated=clamp((light_power-1.0)*0.3,0.0,1.0);
//	float over_saturated=clamp(pow((light_power-1.0)*0.5,2.0),0.0,1.0);
	col=(1.0-over_saturated)*col+over_saturated*normalize(col)*(light_power);
	col.rgb=clamp(col.rgb+is_unshaded*unshaded_faloff*(1.0-material_difference*15.0),0.0,1.0+(1.0-is_unshaded*smp_lod.a)*7.0);
	
	COLOR=col;
	//COLOR=col+vec4(vec3(is_unshaded*unshaded_faloff),1.0);
	//COLOR=vec4(vec3(is_unshaded*unshaded_faloff),1.0);	


}


	