shader_type canvas_item;
uniform sampler2D fog_visual_texture;
uniform float fog_visual_texture_tile=1.0;
uniform vec4 color : source_color = vec4(0.99, 0.49, 0.09, 1.0);

void fragment() {
	vec4 fragColor = texture( TEXTURE, vec2(UV.x,1.0-UV.y) );
	COLOR.a = (1.0 - fragColor.r) * color.a;
	COLOR.rgb = texture(fog_visual_texture,UV*fog_visual_texture_tile).a * color.rgb;
}
