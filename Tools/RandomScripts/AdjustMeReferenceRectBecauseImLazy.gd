@tool
extends EditorScript

func _run() -> void:
	var ref = get_editor_interface().get_edited_scene_root().find_child("ReferenceRect")
	var ui = get_editor_interface().get_edited_scene_root().find_child("GenericUI")
	
	var size = Vector2(820, 420) * ui.scale.x
	ref.size = size
	ref.position = -size / 2
