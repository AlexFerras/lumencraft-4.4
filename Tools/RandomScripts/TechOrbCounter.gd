@tool
extends EditorScript

func _run() -> void:
	var root = get_editor_interface().get_edited_scene_root()
	find_orbs(root)

func find_orbs(node: Node):
	if node is Pickup and node.item == "TECHNOLOGY_ORB":
		print(node.data)
	else:
		for child in node.get_children():
			find_orbs(child)
