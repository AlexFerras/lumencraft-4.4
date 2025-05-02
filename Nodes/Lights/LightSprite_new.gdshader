shader_type canvas_item;
render_mode blend_add;//,skip_vertex_transform;

uniform mat4 global_transform;

uniform sampler2D map_texture;
//uniform sampler2D pixel_map_texture;

uniform sampler2D random_noise;
uniform float shadow_intensity=1.0;
uniform vec2 light_position=vec2(0.0,0.0);

varying vec2 global_position;

uniform int NUM_SAMPLES = 32;
uniform int NUM_SAMPLES_SHORT = 10;
uniform float WEIGHT = 0.3;
uniform float DECAY = 1.0;

float when_neq(float x, float y) {
	return abs(sign(x - y));
}
varying vec2 map_inverse_size;
varying vec2 world_inverse_size;
varying vec2 blur_center;
void vertex()
{
	map_inverse_size = 1.0 / vec2(textureSize(map_texture,0));
//	global_position = (global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
//	VERTEX = (EXTRA_MATRIX * (WORLD_MATRIX * vec4(VERTEX, 1.0, 1.0))).xy;
//	blur_center = (global_transform * vec4(light_position,1.0,1.0)).xy;
// TODO
	//blur_center = (EXTRA_MATRIX * (MODEL_MATRIX * vec4(light_position,1.0,1.0))).xy;

}

float generate_short_shadow( float color, sampler2D map_tex, vec2 cur_pos, vec2 step_size, float rand_noise ) {
	float short_shd = color;
	float illuminationDecay = 0.75;
	for (int i = 0; i < NUM_SAMPLES_SHORT; i++) {
		cur_pos += step_size*0.7;
		vec4 smp = textureLod(map_tex, cur_pos, 0.0);
		//vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size+ normalize(stepSize)*rand*0.003,2.0);
		smp *= illuminationDecay * WEIGHT;
		short_shd += smp.r*1.2;
		illuminationDecay *= DECAY;
	}
	short_shd = min(short_shd,0.7);
	return short_shd;
}
	
float generate_long_shadow( float color, sampler2D map_tex, vec2 cur_pos, vec2 step_size, float rand_noise ) {
	float long_shd = color;
	float illuminationDecay = 1.0;
	for (int i = 1; i < NUM_SAMPLES; i++) {
		cur_pos += step_size;
        
		vec4 smp = textureLod(map_tex, cur_pos + normalize(step_size) * rand_noise*0.003, 0.0);
		//vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size,1.0);
		smp *= illuminationDecay * WEIGHT;
		long_shd += max(smp.a * 0.8  - smp.r*9.0,0.0);
		illuminationDecay *= DECAY;
	}
	return long_shd;
}

void fragment()
{
	vec2 blur_center_ss = (blur_center - vec2(0.5,0.5)) * map_inverse_size;
	vec2 toCenter = (blur_center_ss - SCREEN_UV );
	vec2 stepSize = (toCenter / float(NUM_SAMPLES));
	
	vec4 org_smp = textureLod(map_texture, SCREEN_UV,0.0);
    float org_color = max(org_smp.a-org_smp.b-org_smp.r*2.0,0.0);
	
//	float org_color = textureLod(map_texture, SCREEN_UV,1.0).a;
//	org_color = org_smp.a-org_smp.b;

	float rand = (texture(random_noise,SCREEN_UV * 0.001).r-0.5);


	float long_shadow  = 0.0;
	long_shadow  = generate_long_shadow( org_color, map_texture, SCREEN_UV, stepSize, rand );
	float short_shadow = 0.0;
	short_shadow = generate_short_shadow( org_color-0.5, map_texture, SCREEN_UV, stepSize, rand );

	
	COLOR = vec4(vec3(clamp(max(short_shadow,long_shadow),0.0,1.0))*shadow_intensity , 0.0);
	COLOR = vec4(1.0-COLOR.rgb,1.0)*texture(TEXTURE,UV);
//	COLOR = vec4(blur_center_ss, 0., 1.);
//	COLOR = vec4(SCREEN_UV, 0., 1.);
//	COLOR = texture(TEXTURE,UV);
	
//	COLOR = texture(map_texture,SCREEN_UV);

}


