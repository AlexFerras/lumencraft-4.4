@tool
extends EditorPlugin

var explorer

func _enter_tree() -> void:
	explorer = load("res://addons/DataExplorer/DataExplorer.tscn").instantiate()
	explorer.get_node("Tree").plugin = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR, explorer)

func _exit_tree() -> void:
	remove_control_from_docks(explorer)
	explorer.queue_free()
