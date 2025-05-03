@tool
extends TextureRect

var dock: Control

func _can_drop_data(position: Vector2, data) -> bool:
	if not "type" in data:
		return false
	
	if data.type != "files":
		return false
	
	if data.files.size() != 1:
		return false
	
	return data.files[0].get_extension() == "png"

func _drop_data(position: Vector2, data) -> void:
	texture = load(data.files[0])
	dock.update_controls()
