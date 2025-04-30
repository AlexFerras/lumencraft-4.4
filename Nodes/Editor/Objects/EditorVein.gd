@tool
extends EditorObject

func _init_data():
	defaults.metal_count = 3000
	defaults.has_miner = false

func _configure(editor):
	create_numeric_input(editor, "Metal Count", "metal_count", 0, 999999)
	
	var checkbox := CheckBox.new()
	checkbox.text = "Has miner?"
	checkbox.button_pressed = object_data.get("has_miner", false)
	checkbox.connect("toggled", Callable(self, "set_miner"))
	editor.add_object_setting(checkbox)

func set_miner(miner: bool):
	if miner:
		object_data.has_miner = true
	else:
		object_data.erase("has_miner")
	queue_redraw()

func _draw() -> void:
	if not object_data.get("has_miner", false):
		return
	
	var rect := icon.get_rect()
	rect.position *= icon.scale * 0.2
	rect.size *= icon.scale * 0.2
	draw_texture_rect(preload("res://Nodes/Buildings/Miner/MinerPhoto.png"), rect, false)
