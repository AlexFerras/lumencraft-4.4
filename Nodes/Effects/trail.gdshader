shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D grad;

void fragment()
{
	COLOR= texture(TEXTURE,UV) * texture(grad,UV);
}
