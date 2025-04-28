@tool
extends Sprite2D

var first=true
func _physics_process(delta):
	if first and (not Engine.is_editor_hint() or get_tree().edited_scene_root != self):
		var pixel_map: PixelMap
		if not Engine.is_editor_hint():
			pixel_map = find_parent("PixelMap")
			assert(pixel_map)
		else:
			pixel_map = get_tree().get_edited_scene_root().get_node_or_null("PixelMap")
		
		if pixel_map:
			texture=pixel_map.get_texture()
			pixel_map.connect("texture_changed", Callable(self, "on_texture_change"))
			first = false

	material.set_shader_parameter("global_transform", get_global_transform())

func on_texture_change(t: Texture2D):
	texture = t
