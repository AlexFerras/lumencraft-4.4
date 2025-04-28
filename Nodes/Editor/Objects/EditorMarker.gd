@tool
extends EditorObject

func _init_data():
	defaults.visible = false
	defaults.display_mode = 3

func _configure(editor):
	create_checkbox(editor, "Visible?", "visible")
	
	var label := Label.new()
	label.text = "Display Mode"
	editor.add_object_setting(label)
	
	var options := OptionButton.new()
	options.add_item("All", 3)
	options.add_item("On Minimap", 1)
	options.add_item("On Ground", 2)
	for i in options.get_item_count():
		if options.get_item_id(i) == object_data.display_mode:
			options.selected = i
			break
	
	options.connect("item_selected", Callable(self, "mode_selected").bind(options))
	editor.add_object_setting(options)

func mode_selected(idx: int, options: OptionButton):
	object_data.display_mode = options.get_item_id(idx)

func action_get_events() -> Array:
	return ["show", "hide"]

func _refresh():
	icon.modulate.a = 1.0 if object_data.visible else 0.5
