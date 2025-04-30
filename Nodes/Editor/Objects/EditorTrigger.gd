@tool
extends EditorObject

var object_list: OptionButton

func _init() -> void:
	can_rotate = true

func _init_data():
	defaults.width = 64
	defaults.height = 16

func _configure(editor):
	create_numeric_input(editor, "Width", "width")
	create_numeric_input(editor, "Height", "height")

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_rect(Rect2(-object_data.width / 2, -object_data.height / 2, object_data.width, object_data.height), Color.AQUAMARINE, false, 2)

func get_condition_list() -> Array:
	return ["player_entered*", "player_inside", "enemy_entered*", "enemy_inside", "object_entered*", "object_inside"]

func get_additional_config(editor, condition_action: String) -> Control:
	if condition_action == "object_entered" or condition_action == "object_inside":
		var vb := VBoxContainer.new()
		
		var label := Label.new()
		vb.add_child(label)
		label.text = "Filter Objects"
		
		object_list = OptionButton.new()
		vb.add_child(object_list)
		object_list.add_item("Any")
		object_list.add_item("Flare")
		object_list.add_item("Pickup")
		object_list.add_item("Chest")
		object_list.add_item("Rusty Chest")
		object_list.add_item("Explosive Barrel")
		object_list.add_item("Boulder")
		object_list.add_item("Lumen Chunk")
		editor.register_data("filter", Callable(self, "set_selected"), Callable(self, "get_selected"))
		
		return vb
	
	return null

func set_selected(selected):
	for i in object_list.get_item_count():
		if object_list.get_item_text(i) == selected:
			object_list.selected = i
			return

func get_selected():
	return object_list.get_item_text(object_list.selected)
