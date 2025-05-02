@tool
extends EditorScript

func _run() -> void:
	print(count_nodes(get_editor_interface().get_edited_scene_root()))

func count_nodes(node: Node):
	var count := 1
	for child in node.get_children():
		count += count_nodes(child)
	return count
