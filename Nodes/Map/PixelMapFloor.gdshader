shader_type canvas_item;    


uniform float tar_index=24.0;
uniform vec4 tar_color=vec4(1.0);
uniform vec4 tar_border_color=vec4(1.0);
uniform sampler2D tar_texture;

uniform mat4 global_transform;

varying vec2 global_position;

void vertex() {
	global_position=(global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
}



void fragment () {


	vec2 tex_size=vec2(textureSize(TEXTURE,0));
	vec2 inv_size=1.0/tex_size;
	vec4 real_col=texelFetch(TEXTURE, ivec2(global_position),0);

	float resource_type=real_col.g*255.0;

	vec4 smp_lod = textureLod(TEXTURE, (global_position)*inv_size,2.0);

	COLOR=vec4(0.0,0.0,0.0,0.0);
	
	float material_difference=abs(real_col.g-smp_lod.g);
	float unshaded_faloff=pow(smp_lod.a,2);
	

	if(abs(resource_type-tar_index)<0.1)
	{
		float fadeoff=unshaded_faloff;
		vec4 tar= vec4(texture(tar_texture,global_position*0.02).rgb*tar_color.rgb*(1.0-min(fadeoff*1800.0,0.5)),(tar_color.a));
		float alpha=max(tar.a-(1.-unshaded_faloff),0.0);

		COLOR=COLOR*(1.0-alpha)+ vec4(tar*alpha);
		COLOR*=1.0+(1.0-smp_lod.a)*tar_border_color*5.0;


	}
	//COLOR.rgb-=is_unshaded*100.0*is_unshaded;
	

	
	
	//COLOR = vec4(ster.rgb,1.0);
}


//void fragment () {
//    vec4 result;
//    vec4 ster = textureLod(TEXTURE, UV+0.005*(textureLod(noise,UV*5.0,0.5).rg-0.5),mip_map);
//
//    vec4 color1 = texture(texture1, UV*resolution1);
//    vec4 color2 = texture(texture2, UV*resolution1);
//    vec4 color3 = texture(texture3, UV*resolution1);
//    vec4 color4 = texture(texture4, UV*resolution1);
//    result = blend(color1,1.0-ster.g,color2,ster.g,depth1);
//    COLOR = result;
//    //COLOR = vec4(ster.rgb,1.0);
//}