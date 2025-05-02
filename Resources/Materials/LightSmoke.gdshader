shader_type canvas_item;
render_mode blend_add;

uniform int smoke_OCTAVES = 6;
uniform float smoke_speed = 2.0;
uniform float smoke_variation_speed = 1.0;
uniform float smoke_variation_mul = 1.0;
uniform float smoke_treshold = 0.1;
uniform vec4 smoke_color = vec4(1.0);


float rand(vec2 coord){
	return fract(sin(dot(coord, vec2(12.9898, 78.233)))* 43758.5453123);
}

float noise(vec2 coord){
	vec2 i = floor(coord);
	vec2 f = fract(coord);

	// 4 corners of a rectangle surrounding our point
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));

	vec2 cubic = f * f * (3.0 - 2.0 * f);

	return mix(a, b, cubic.x) + (c - a) * cubic.y * (1.0 - cubic.x) + (d - b) * cubic.x * cubic.y;
}

float fbm(vec2 coord){
	float value = 0.0;
	float scale = 0.5;

	for(int i = 0; i < smoke_OCTAVES; i++){
		value += noise(coord) * scale;
		coord *= 2.0;
		scale *= 0.5;
	}
	return value;
}


void fragment()
{
	//SMOKE
	vec4 color = texture( TEXTURE, UV );
	vec2 scaled_coord = UV * vec2(textureSize(TEXTURE,0))*0.05;

	float motion_fbm = fbm(scaled_coord + vec2(TIME * 0.08, TIME * .06)*smoke_speed); // used for distorting the smoke_fbm texture
	float smoke_fbm = fbm(scaled_coord + vec2(-TIME*.02, TIME * -.04)*smoke_variation_speed + motion_fbm*smoke_variation_mul);


	smoke_fbm = clamp(smoke_fbm - smoke_treshold, 0.0, 1.0) / (1.0 - smoke_treshold);
	if (smoke_fbm < 0.1) {
		smoke_fbm *= smoke_fbm/0.1;
	}
	smoke_fbm = sqrt(smoke_fbm);
	COLOR = vec4((vec3(clamp(smoke_fbm*0.5,0.0,1.0))*smoke_color.rgb)*smoke_fbm,smoke_color.a) * color.a ;
	COLOR.a = COLOR.r ;
	//SMOKE end
}