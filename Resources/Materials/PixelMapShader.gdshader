shader_type canvas_item;
render_mode skip_vertex_transform ;

uniform mat4 global_transform;


uniform float random_blur =0.5;
uniform float shuffle_tile_border =4.0;
uniform float blur_amount =1.5;
uniform float random_blur_border =4.0;
uniform float random_noise_mul =2.0;


uniform float dirt_tile_mul =8.0;

uniform sampler2D crack_tiled:repeat_enable;
uniform float crack_tile_mul =5.0;

uniform sampler2D noise_tiled:repeat_enable;
uniform float noise_tile_mul =30.0;

uniform sampler2D random_noise:repeat_enable;


uniform sampler2DArray terrain_texture_mix:repeat_enable;
uniform sampler2D wall_texture:repeat_enable;
uniform sampler2D lumen_texture:repeat_enable;
uniform float wall_mul =4.0;
uniform float show_hidden=0.0;



uniform sampler2D magma:repeat_enable;
uniform vec4 magma_color  :	source_color= vec4( 2.89, 1.16, 0.0, 1.0);

uniform sampler2D water_noise:repeat_enable;
uniform vec4 water_color  :	source_color= vec4(0.8,1.2,2.4,1.0);
uniform sampler2D caustics:repeat_enable;
uniform float caustics_mul =15.0;

uniform vec4 lumen_color;
uniform vec4 lumen_glitter_color;
uniform float lumen_mul;
uniform float lumen_glitter_power;
uniform sampler2D lava_data: hint_default_black, repeat_enable;
uniform int lava_data_count;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap, repeat_enable;

const float black_fade_array[33] = {4.0, 2.0, 6.0, 1.0, 1.0, 9.0, 7.0, 1.0, 1.0, 1.0, 
									1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 8.0,
									1.0, 8.0, 8.0, 8.0, 1.0, 10.0/* 25 empty*/, 8.0, 12.0, 1.0, 1.0, 
									9.0,1.0,0.0};

varying vec2 worldUV;

float random( vec2 p )
{
    vec2 K1 = vec2(
        23.14069263277926, // e^pi (Gelfond's constant)
         2.665144142690225 // 2^sqrt(2) (Gelfondâ€“Schneider constant)
    );
    return fract( cos( dot(p,K1) ) * 12345.6789 );
}


void vertex() {
	
// VERTEX=(WORLD_MATRIX*vec4(VERTEX,1.0,1.0)).xy;
 VERTEX  = (global_transform * vec4(VERTEX, 0.0, 1.0)).xy;
// UV=(vec4(UV,1.0,1.0)*inverse(WORLD_MATRIX)).xy;
}

float when_eq(float x, float y) {
  return 1.0 - abs(sign(x - y));
}

float when_neq(float x, float y) {
  return abs(sign(x - y));
}




vec4 get_shuffled_color(vec2 UV_in, sampler2D map_texture, vec2 random_blur_scaled, vec2 UV_in_scaled, vec2 tex_size)
{
	//vec4 col_res=textureLod(map_texture, UV_in+17.0* random_blur_scaled*(texture(random_noise,UV_in_scaled*vec2(4.0)).rg-0.5),0.0);
	vec4 col_res=texelFetch(map_texture, ivec2((UV_in+17.0* random_blur_scaled*(texture(random_noise,UV_in_scaled*shuffle_tile_border).rg-vec2(0.5,0.5)))*tex_size),0);

	return col_res;
}

vec4 getWaterColor(sampler2D map_texture,vec2 UV_in, sampler2D SCREEN_TEXTURE_in, vec2 SCREEN_UV_in, float tim)
{
	UV_in*=0.4;
	vec4 outCOLOR=vec4(0.0);
	
		    // this is the waves moving under the texture
    float textureOffset = tim / 90.0;
    vec2 waveOne = UV_in*3.0 + vec2(textureOffset, textureOffset);
    
    vec4 sampleOne = texture(water_noise, waveOne)*0.01 ;
        
    textureOffset += tim / 140.0;
    vec2 waveTwo = UV_in*5.0 - vec2(textureOffset, -textureOffset);
    vec4 sampleTwo = texture(water_noise, waveTwo)*0.01;
    
	vec2 calc_uv= sampleOne.xy + sampleTwo.xy;
		
	outCOLOR =  texture(SCREEN_TEXTURE_in, calc_uv+SCREEN_UV_in-vec2(0.01,0.007)) * water_color;
	outCOLOR.rgb+=vec3(pow(textureLod(caustics,caustics_mul*UV_in +calc_uv-tim*0.02,2.54).r,8.0)*0.5);
	float textureOffset_spec = tim / 40.0;
    vec2 waveOne_spec = UV_in*30.0 + vec2(textureOffset_spec, textureOffset_spec);
    vec4 sampleOne_spec = texture(water_noise, waveOne_spec) ;
		
	
	textureOffset_spec = tim / 44.0;
    vec2 waveTwo_spec = UV_in*20.0 - vec2(textureOffset_spec, textureOffset_spec);
    vec4 sampleTwo_spec = texture(water_noise, waveTwo_spec);
    

	
//
	vec4 col=(sampleTwo_spec+sampleOne_spec)*0.5;
//		float col_len=length(col)-1.4;
//		if(col_len<0.1)
//			COLOR+=	((0.1-(col_len))*vec4(0.5,0.5,1.0,1.0)*col.r*8.0)
//		}

	if(col.b>0.95)
		outCOLOR+=	vec4(0.5,0.5,1.0,0.0)*(col.b-0.95)*30.0;

	if(col.g>0.6)
		outCOLOR+=	vec4(1.0,1.0,1.0,0.0)*(col.g-0.6)*1.5;

	outCOLOR=clamp(outCOLOR,vec4(0.0),vec4(1.4));

	
	
	return outCOLOR;
}

vec4 getLavaColor(sampler2D map_texture,vec2 UV_in, sampler2D SCREEN_TEXTURE_in, vec2 SCREEN_UV_in, float tim)
{
	UV_in*=0.4;
	vec4 outCOLOR=vec4(0.0);
	vec2 t=vec2(tim*0.005);
    vec3 field = textureLod(magma,UV_in*50.0*0.5+t*0.45,1.0).rgb + vec3(230,127,25)/255.;
    float lum = textureLod(magma,UV_in*50.0*0.5-t*3.5+(field.rg-field.gb)/2.,1.0).g*1.0;
	outCOLOR = vec4(lum*magma_color.rgb,0.5)*2.8;
	return outCOLOR;
}



mat2 makem2(in float theta){float c = cos(theta);float s = sin(theta);return mat2(vec2(c,-s),vec2(s,c));}
float noise( in vec2 x ){return texture(random_noise, x*.01).x;}

vec2 gradn(vec2 p)
{
	float ep = 0.9;
	float gradx = noise(vec2(p.x+ep,p.y))-noise(vec2(p.x-ep,p.y));
	float grady = noise(vec2(p.x,p.y+ep))-noise(vec2(p.x,p.y-ep));
	return vec2(gradx,grady);
}

float flow(in vec2 p,float time,float lava_dist,vec2 vec_from_source)
{
	float z=20.;
	float rz = 0.01;
	vec2 bp = p;
	for (float i= 1.;i < 4.;i++ )
	{
		float m_distance = length(vec_from_source);
		float sin_dist = sin((length(vec_from_source) -time*110.01)*0.1 )*10.110;
		vec2 shiftedUV= ( normalize(vec_from_source)*(sin_dist+12.0) );

		
		//primary flow speed
		p += shiftedUV*0.012*lava_dist;
		
		
	
		
		//secondary flow speed (speed of the perceived flow)
		bp += shiftedUV*0.07*1.0*lava_dist;
		
		//displacement field (try changing time multiplier)
		vec2 gr = gradn(i*p*0.5+time*1.00);
		
		//rotation of the displacement field
		gr*=makem2(time*6.-(0.05*p.x+0.03*p.y)*40.);
		
		//displace the system
		p += gr*.15;
		
		//add noise octave
		rz+= (sin(noise(p)*7.)*0.5+0.6)/(z*(lava_dist+0.1));
		
		//blend factor (blending displaced system with base system)
		//you could call this advection factor (.5 being low, .95 being high)
		p = mix(bp,p,1.07);
		
		//intensity scaling
		z *= 1.4;
		//octave scaling
		p *= 5.;
		bp *= 5.01;
	}
	return rz;	
}




vec4 getLava2Color(sampler2D map_texture,vec2 UV_in, float tim, vec4 lava_posx_posy_radius)
{

	
	vec2 lava_source=vec2(lava_posx_posy_radius.r,lava_posx_posy_radius.g);
	float lava_radius=lava_posx_posy_radius.b;
	float lava_dist=clamp((lava_radius-distance(UV_in*1000.0,lava_source))/lava_radius,0.05,1.0);


	float rz = flow(UV_in*40.4,tim*0.1,lava_dist,UV_in*1000.0-lava_source)*0.3;
	
	vec3 col = vec3(.2,0.07,0.01)/rz;
	//col=pow(col,vec3(1.3));

	return vec4(col.rgb*0.25,1.0);
}

vec3 addCracks(vec2 UV_in_scaled, vec4 real_col, vec4 col)
{
	vec4 crack=texture(crack_tiled, vec2(UV_in_scaled*crack_tile_mul)); 
	vec4 crack_small=texture(crack_tiled, vec2(UV_in_scaled*crack_tile_mul)*3.0); 
	//commented section is to disable cracks on some material	
	float healthy=clamp(1.0-(pow(real_col.r, 2.0)/*+is_res1*/),0.0,1.0);
	return col.a*(((1.0-crack.rgb*1.0)*healthy+(3.0-crack_small.rgb*3.0)*clamp(healthy-0.6,0.0,1.0))); //crack damaged terrain	
}


vec4 getMapColor(sampler2D map_texture,vec2 UV_in, sampler2D SCREEN_TEXTURE_in, vec2 SCREEN_UV_in, float tim)
{
	
	float dirt_number=0.0;
	float water_number=240.0/255.0;
	float magma_number=248.0/255.0;
	float res1_number=8.0/255.0;
	float res2_number=16.0/255.0;
	vec2 tex_size=vec2(textureSize(map_texture,0));
	vec2 inv_size=1.0/tex_size;
	float aspect = inv_size.y/inv_size.x;
	//UV_in=(vec2(ivec2(UV_in*8192.0))/8192.0);
	
	//vec4 real_col=texture(map_texture, UV_in);
	vec4 real_col=texelFetch(map_texture, ivec2(UV_in*tex_size),0);
	
	
	//float is_hidden=clamp(float(real_col.b*1.0),0.0,1.0)*show_hidden;
	vec2 UV_in_scaled=UV_in*tex_size*0.001;
	vec2 random_blur_scaled=random_blur*inv_size;
	vec2 random_blur_border_scaled=random_blur_border*inv_size;
	
	//used for alpha
	//vec4 col=textureLod(map_texture, UV_in+ random_blur_scaled* (texture(random_noise,UV_in_scaled*random_noise_mul).r-0.5),blur_amount);
	vec4 col=textureLod(map_texture, UV_in+ random_blur_border_scaled* (texture(random_noise,UV_in_scaled*random_noise_mul).rg-vec2(0.55)),blur_amount);
	//vec4 col_zero=textureLod(map_texture, UV_in+ random_blur_border_scaled* (texture(random_noise,UV_in_scaled*random_noise_mul).rg-vec2(0.55)),0);
	vec4 col_zero=texelFetch(map_texture, ivec2((UV_in+ random_blur_border_scaled* (texture(random_noise,UV_in_scaled*random_noise_mul).rg-vec2(0.55)))*tex_size),0);

	// used for material shuffling
	vec4 col_res=get_shuffled_color(UV_in,map_texture,random_blur_scaled,UV_in_scaled,tex_size);
	
	
	
	
	float same=0.0;
	vec2 check=5.0*inv_size;
	float alf=0.0;
	vec4 col_res_other[4];
	col_res_other[0]=get_shuffled_color(UV_in+check,map_texture,random_blur_scaled,UV_in_scaled,tex_size);
	vec4 col_res2=col_res_other[0];
	same+=when_eq(col_res.g,col_res2.g) ;
	alf+=col_res2.a;

	col_res_other[1]=get_shuffled_color(UV_in+check*vec2(1,-1),map_texture,random_blur_scaled,UV_in_scaled,tex_size);
	col_res2=col_res_other[1];
	same+=when_eq(col_res.g,col_res2.g) ;
	alf+=col_res2.a;

	col_res_other[2]=get_shuffled_color(UV_in+check*vec2(-1,1),map_texture,random_blur_scaled,UV_in_scaled,tex_size);
	col_res2=col_res_other[2];
	same+=when_eq(col_res.g,col_res2.g);
	alf+=col_res2.a;

	col_res_other[3]=get_shuffled_color(UV_in+check*vec2(-1,-1),map_texture,random_blur_scaled,UV_in_scaled,tex_size);
	col_res2=col_res_other[3];
	same+=when_eq(col_res.g,col_res2.g);
	alf+=col_res2.a;
	
	vec4 outCOLOR;
	float resource_type=(real_col.g*255.0);
	bool isFluid=resource_type>=28.8 && resource_type<31.5;
	bool isTransparent = (real_col.b>0.0 && !isFluid) || resource_type==24.0;
	bool isTransparentMip = col.b>6.9/255.0 && !isFluid;
	
	resource_type=real_col.g*255.0;
	if(abs(resource_type-27.0)<0.1)
	{
		outCOLOR=texture(lumen_texture,vec2(UV_in_scaled*dirt_tile_mul*wall_mul))*lumen_color;
		
		outCOLOR.rgb=outCOLOR.rgb+0.8*addCracks(UV_in_scaled,real_col,col);
		
		outCOLOR.rgb +=(1.0-(texture(crack_tiled, UV_in*110.3).r)) * 0.55;
		
			
	    float result = 0.0;
	    result += texture(random_noise, UV_in_scaled * 2.1045 + vec2(tim*-0.005)).r;
	    result *= texture(random_noise, UV_in_scaled * 2.104 + vec2(tim*+0.005)).g;
	    result = pow(result, lumen_glitter_power);
		
	    outCOLOR = (outCOLOR+ lumen_mul*lumen_glitter_color*result);

	}
	else if(abs(resource_type-26.0)<0.1)
	{
		outCOLOR=texture(lumen_texture,vec2(UV_in_scaled*dirt_tile_mul*wall_mul*2.0));
		outCOLOR=vec4(outCOLOR.b,outCOLOR.b*2.0,outCOLOR.b*2.0,1.0);
		
		outCOLOR.rgb=outCOLOR.rgb+0.8*addCracks(UV_in_scaled,real_col,col);
		
		outCOLOR.b +=(1.0-(texture(crack_tiled, UV_in*110.3).r)) * 1.55;
		
		
	    float result = 0.0;
	    result += texture(random_noise, UV_in_scaled * 10.1045 + vec2(tim*-0.001)).r;
	    result *= texture(random_noise, UV_in_scaled * 10.104 + vec2(tim*+0.005)).g;
	    result = pow(result, 4.0);
		
	    outCOLOR = (outCOLOR+ lumen_mul*vec4(0.0,0.6,0.9,0.0)*result);
			
	}
	else if(abs(resource_type-29.0)<0.1)
		outCOLOR= getWaterColor(map_texture,UV_in_scaled,SCREEN_TEXTURE_in,SCREEN_UV_in,tim);
	else if(abs(resource_type-30.0)<0.1)
	{
		int lava_source_id=clamp(int(real_col.b*255.0),0,lava_data_count-1);
		vec4 lava_posx_posy_radius = texelFetch(lava_data, ivec2(lava_source_id,0), 0);
		outCOLOR= getLava2Color(map_texture,UV_in_scaled,tim,lava_posx_posy_radius);
	}
	else
	{
		outCOLOR=texture(terrain_texture_mix,vec3(UV_in_scaled*dirt_tile_mul, resource_type )      );
		outCOLOR.rgb=max(vec3(0.0),(outCOLOR.rgb-addCracks(UV_in_scaled,real_col,col)));
	}

	
	//Po co to na dole bylo??
	//outCOLOR.a=clamp((16.0-((resource_type*255.0+0.0)*0.125)),0.0,1.0);
	//outCOLOR.a-=clamp(float(real_col.b*2586.0),0.0,1.0)*show_hidden;

/*
	float is_water_for=0.0;
	float water_check=6.0;
	vec4 water_check1 =texture(map_texture, UV_in+vec2(water_check,water_check)/tex_size);
	vec4 water_check2 =texture(map_texture, UV_in+vec2(-water_check,-water_check)/tex_size);
	vec4 water_check3 =texture(map_texture, UV_in+vec2(water_check,-water_check)/tex_size);
	vec4 water_check4 =texture(map_texture, UV_in+vec2(-water_check,water_check)/tex_size);

	is_water_for+=float(water_check1.g==water_number);
	is_water_for+=float(water_check2.g==water_number);
	is_water_for+=float(water_check3.g==water_number);
	is_water_for+=float(water_check4.g==water_number);


	//is_water_for=clamp(is_water_for,0.0,100.0);
	float is_water_for_normalized=is_water_for*0.0025;
	float is_water_for_clamped=clamp(is_water_for,0.0,1.0);
	float is_water=float(col_res.g==water_number);
	*/
	//dirt=col_res;
	//x coord multipled because of aspect ratio
	
	if(noise_tile_mul>0.0)
	{
		vec4 noise=texture(noise_tiled, UV_in_scaled*noise_tile_mul);
		outCOLOR.rgb*=0.4+noise.rgb; // darker patches
	}
	

	//float is_water_border=min(((1.0-is_non_trans)*is_water_for_clamped)+is_water,1.0);
	//if(col.a<cutoff)
	{
		//DARK AMBIENT, FROM BORDER OF TERRAIN TO EMPTY
		outCOLOR.rgb-=1.0*(1.0-col.a);
		outCOLOR.rgb*=pow(col.a,3.0);
		//outCOLOR.a=pow(min(1.0,col.a),0.6);
		//outCOLOR.a=pow(min(float(!isTransparentMip),col.a),0.6);
		outCOLOR.a *= pow(min(1.0,clamp((col.a-col.b),0.0,1.0)),0.6);

		
		//outCOLOR.a=pow(col.a*float(!isTransparentMip),0.6);
		//outCOLOR.a=col.a;
	//	outCOLOR=(col.g>0.9/255.0)?vec4(1.0):vec4(0.0);

		//outCOLOR.a=col.a;
	//	outCOLOR.rgb-=(is_water_border)*vec3(0.8,0.0,0.0);
	//	outCOLOR.a+=(is_water_border)*0.1*col.a/cutoff;
		//outCOLOR-=is_water*vec4(0.0,0.0,1.0,0.1)*1.0;

	}
	
	
	//Shadow between different resources
	outCOLOR.rgb*=pow(clamp(0.25*same+(4.0-alf),0.5,1.0),0.8);

	float difference_material_type= abs(col.g-real_col.g);
	float max_material_diff= abs(real_col.g - col_res_other[0].g);
	max_material_diff= max(max_material_diff, abs(real_col.g - col_res_other[1].g));
	max_material_diff= max(max_material_diff, abs(real_col.g - col_res_other[2].g));
	max_material_diff= max(max_material_diff, abs(real_col.g - col_res_other[3].g));
	max_material_diff=max_material_diff;
	
	float fade_multipler = black_fade_array[min(int(real_col.g*255.0+0.5),32)];
	for(int i = 0; i < 4; ++i)
	{
		fade_multipler = max(black_fade_array[min(int(col_res_other[i].g*255.0+0.5),32)], fade_multipler);
	}
//	if(max_material_diff > 0.001) outCOLOR.rgb=outCOLOR.rgb*pow(1.0-min(((difference_material_type)/(max_material_diff))*0.2*(black_fade_array[min(int(real_col.g*255.0+0.5),32)]), 1.0),2.0);
	if(max_material_diff > 0.001) outCOLOR.rgb=outCOLOR.rgb*pow(1.0-min(((difference_material_type)/(max_material_diff))*0.2*fade_multipler, 1.0),2.0);
	//outCOLOR.rgb=black_fade_array[min(int((real_col.g)*255.0+0.5),32)]*vec3(1.0);
	//return outCOLOR;
	return outCOLOR*(isFluid?1.0:float(!isTransparent));
}

vec4 getMapColor2(sampler2D map_texture,vec2 UV_in, sampler2D SCREEN_TEXTURE_in, vec2 SCREEN_UV_in, float tim)
{
	float resource_type=0.0;
	vec4 outCOLOR=texture(terrain_texture_mix,vec3(UV_in*dirt_tile_mul,resource_type));
	
	return outCOLOR;
}
void fragment()
{		
	if(AT_LIGHT_PASS)
		discard;
	
	
	
	/*
	NORMAL_MAP=texture(NORMAL_TEXTURE,UV*dirt_tile_mul*4.0).rgb;
	NORMAL_MAP.r=1.0-NORMAL_MAP.r;
	NORMAL_MAP_DEPTH=0.3;*/
	 
	//COLOR = vec4(1, 1, 1, 0.0);
	COLOR=getMapColor(TEXTURE,UV,SCREEN_TEXTURE,SCREEN_UV,TIME);

	
	//COLOR=vec4(vec3(textureLod(map_texture,UV,blur_amount).r),1.0) ;
}