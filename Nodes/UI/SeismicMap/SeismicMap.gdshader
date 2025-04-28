shader_type canvas_item;

uniform vec2 res; 
uniform vec3 indicator_data;

void fragment() {
	vec2 pixel = UV * res;
	float fragColor = texture(TEXTURE, SCREEN_UV).r;
	float xPixel = 1.0 / res.x;
	float yPixel = 1.0 / res.y;
	
	float dist2 = distance(indicator_data.xy, pixel);
	if (indicator_data.z > 0.0 && dist2 < indicator_data.z) {
		fragColor += (1.0 - (dist2 / indicator_data.z)) * 10.0;
	}
	
	float rightColor = texture(TEXTURE, vec2(SCREEN_UV.x + xPixel, SCREEN_UV.y)).r;
	float leftColor = texture(TEXTURE, vec2(SCREEN_UV.x - xPixel, SCREEN_UV.y)).r;
	float upColor = texture(TEXTURE, vec2(SCREEN_UV.x, SCREEN_UV.y + yPixel)).r;
	float downColor = texture(TEXTURE, vec2(SCREEN_UV.x, SCREEN_UV.y - yPixel)).r;
	
	float factor = 14.0 * 0.016 * (leftColor + rightColor + downColor + upColor - 4.0 * fragColor);
	
	float minimum = 0.012;
	if (factor >= -minimum && factor < 0.0) {
		factor = -minimum;
	} 
	
	fragColor += factor;
	COLOR.a = 1.0;
    COLOR.rgb = vec3(fragColor);
}

//void fragment() {
//	vec2 pixel = UV * res;
//	vec4 fragColor = texture(TEXTURE, SCREEN_UV);
//	float xPixel = 1.0 / res.x;
//	float yPixel = 1.0 / res.y;
//
//	float dist2 = distance(indicator_data.xy, pixel);
//	if (indicator_data.z > 0.0 && dist2 < indicator_data.z) {
//		fragColor.rgb += (1.0 - (dist2 / indicator_data.z)) * 10.0;
//	}
//
//	vec4 rightColor = texture(TEXTURE, vec2(SCREEN_UV.x + xPixel, SCREEN_UV.y));
//	vec4 leftColor = texture(TEXTURE, vec2(SCREEN_UV.x - xPixel, SCREEN_UV.y));
//	vec4 upColor = texture(TEXTURE, vec2(SCREEN_UV.x, SCREEN_UV.y + yPixel));
//	vec4 downColor = texture(TEXTURE, vec2(SCREEN_UV.x, SCREEN_UV.y - yPixel));
//
//	float factor = 14.0 * 0.016 * (leftColor.r + rightColor.r + downColor.r + upColor.r - 4.0 * fragColor.r);
//
//	float minimum = 0.006;
//	if (factor >= -minimum && factor < 0.0) {
//		factor = -minimum;
//	} 
//
//	fragColor.rgb += factor;
//	COLOR.a = 1.0;
//    COLOR.rgb = fragColor.rgb;
//}