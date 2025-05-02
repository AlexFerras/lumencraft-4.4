shader_type canvas_item;
render_mode blend_add,skip_vertex_transform;

uniform mat4 global_transform;
uniform sampler2D map_texture;
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
varying vec2 blur_center;
void vertex()
{
	map_inverse_size=1.0/vec2(textureSize(map_texture,0));
	global_position=(global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
	// TODO
	//VERTEX = (EXTRA_MATRIX * (MODEL_MATRIX * vec4(VERTEX, 1.0, 1.0))).xy;

    blur_center = (global_transform*vec4(light_position,1.0,1.0)).xy;
	
}


void fragment()
{
 
    vec2 currentPosition = global_position; 
    vec2 toCenter = (blur_center-currentPosition );
    vec2 stepSize = (toCenter / float(NUM_SAMPLES));
	
	vec4 org_smp=textureLod(map_texture, (currentPosition)*map_inverse_size,1.0);
    float org_color = org_smp.a-org_smp.b;
	
	float rand=(texture(random_noise,global_position*0.01).r-0.5);
//	org_color=0.0;
   	float color = org_color;
    float long_shadow = org_color;
    float short_shadow = org_color-0.7;


    float illuminationDecay = 1.0;
    for (int i = 1; i < NUM_SAMPLES; i++) {
    	currentPosition += stepSize;
        vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size + normalize(stepSize)*rand*0.003,1.0);
        //vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size,1.0);

		
		float isBuilding=float(abs(smp.y-(27.0/255.0))>3.1/255.0);

		
        smp *= illuminationDecay * WEIGHT*isBuilding;
        long_shadow += (smp.a-smp.b)*0.3;
        illuminationDecay *= DECAY;
    }
	
	
	currentPosition = global_position;
	illuminationDecay=0.75;

	for (int i = 1; i < NUM_SAMPLES_SHORT; i++) {
    	currentPosition += stepSize*1.0;
		vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size,2.0);
        //vec4 smp = textureLod(map_texture, (currentPosition)*map_inverse_size+ normalize(stepSize)*rand*0.003,2.0);
		smp *= illuminationDecay * WEIGHT;
		short_shadow += smp.a-smp.b;
		short_shadow=min(short_shadow,0.8);
		illuminationDecay *= DECAY;
	}
	
	
	
    COLOR = vec4(vec3(clamp(max(short_shadow,long_shadow),0.0,1.0))*shadow_intensity , 0.0);
    COLOR=vec4(1.0-COLOR.rgb,1.0)*texture(TEXTURE,UV);

	

}


