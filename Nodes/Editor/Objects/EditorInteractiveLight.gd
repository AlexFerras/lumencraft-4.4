@tool
extends EditorObject

@export var type: String

var grid

func _ready() -> void:
	modulate = object_data.color

func _init_data():
	defaults.color = Color.GREEN
	defaults.offset = 0
	defaults.duration = 0.5
	defaults.pattern = [true, false]

func _configure(editor):
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = "Color"
	hbox.add_child(label)
	
	var color := ColorPickerButton.new()
	color.color = object_data.color
	color.edit_alpha = false
	color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color.connect("color_changed", Callable(self, "on_color_changed"))
	hbox.add_child(color)
	
	editor.add_object_setting(hbox)
	
	create_numeric_input(editor, "Time Offset", "offset", 0, 100, false, 0.01)
	create_numeric_input(editor, "Blink Duration", "duration", 0.01, 20, false, 0.01)
	
	var pattern_size = create_numeric_input(editor, "Pattern Size", "", 2, 30)
	pattern_size.value = object_data.pattern.size()
	pattern_size.connect("value_changed", Callable(self, "set_pattern_size"))
	
	label = Label.new()
	label.text = "Blink Pattern"
	editor.add_object_setting(label)
	
	grid = preload("res://Nodes/Editor/GUI/GridEdit.tscn").instantiate()
	editor.add_object_setting(grid)
	grid.set_amount(object_data.pattern.size())
	grid.set_mask(object_data.pattern)
	grid.connect("changed", Callable(self, "grid_changed"))

func set_pattern_size(size):
	grid.set_amount(size)

func on_color_changed(color: Color):
	object_data.color = color
	emit_signal("data_changed")
	modulate = color

func grid_changed():
	object_data.pattern = grid.get_mask()
	emit_signal("data_changed")
