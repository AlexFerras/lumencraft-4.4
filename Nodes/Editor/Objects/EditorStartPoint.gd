@tool
extends EditorObject

func _ready() -> void:
	for object in get_parent().get_children():
		if object != self and object.object_name == object_name:
			object.destroy()
			return
