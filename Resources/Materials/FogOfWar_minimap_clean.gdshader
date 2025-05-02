shader_type canvas_item;
void fragment() {
	float red = texture( TEXTURE, vec2(UV.x, 1.0-UV.y) ).r;
	COLOR.a = (1.0 - red);
	COLOR.rgb = vec3(0.0);
}
