shader_type canvas_item;

uniform sampler2D fog_texture;
uniform bool hide_fog = false;
uniform float cutoff = 1.5;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float fog = texture(fog_texture, vec2(UV.x, UV.y)).r;
	float white = step(cutoff,color.r+color.g+color.b);
	color.a = min(fog + float(hide_fog) + white, 1.0);
	COLOR = color;
}