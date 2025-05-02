@tool
extends EditorScript

func _run() -> void:
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		return
	
	selected = selected.front()
	if selected is AudioStreamPlayer2D:
		selected.attenuation = 2
		selected.max_distance = 500
		selected.bus = "SFX"
