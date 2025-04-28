@tool
extends EditorObject

var index_input: SpinBox
var warning_label: Label

func _init_data():
	defaults.index = -1

func _ready() -> void:
	add_to_group("goals")

func _configure(editor):
	index_input = create_numeric_input(editor, "Index", "index", 0, get_max_index())
	index_input.connect("tree_exited", Callable(self, "set").bind("index_input", null))
	
	if not is_placed():
		index_input.editable = false
		index_input.tooltip_text = "Can be only modified after placing."
	
	var label := Label.new()
	label.text = "Time Limit"
	label.hide() ## temporary
	editor.add_object_setting(label)
	
	var time = preload("res://Nodes/Editor/GUI/Time.tscn").instantiate()
	time.set_time(object_data.get("time_limit", 0))
	time.connect("time_changed", Callable(self, "on_time_changed"))
	time.hide() ## temporary
	editor.add_object_setting(time)
	
	label = Label.new()
	label.text = "Custom Objective Text"
	editor.add_object_setting(label)
	
	var line_edit := LineEdit.new()
	line_edit.max_length = 80
	line_edit.text = object_data.get("message", "")
	line_edit.connect("text_changed", Callable(self, "on_message_changed"))
	editor.add_object_setting(line_edit)
	
	warning_label = Label.new()
	warning_label.text = "Note: Custom objective text only has effect when map objective is \"All Goals In Order\"."
	warning_label.autowrap = true
	if Utils.editor.objective_settings.get_data().win.type != "finish" or Utils.editor.objective_settings.get_data().win.goal_type != 2:
		warning_label.modulate = Color.RED
	refresh_warning_label()
	editor.add_object_setting(warning_label)

func refresh_warning_label():
	warning_label.visible = bool(object_data.get("message", ""))

func on_message_changed(text: String):
	if text.is_empty():
		object_data.erase("message")
	else:
		object_data.message = text
	refresh_warning_label()

func on_time_changed(time: float):
	if time > 0:
		object_data.time_limit = time
	else:
		object_data.erase("time_limit")

func _on_placed():
	if object_data.get("index", -1) > -1:
		return
	
	object_data.index = get_max_index() + 1

func _set_object_data_callback(value, field: String):
	if field == "index":
		for goal in get_tree().get_nodes_in_group("goals"):
			if goal.object_data.get("index", -1) == value:
				goal.object_data.index = object_data.index
	
	super._set_object_data_callback(value, field)

func get_max_index() -> int:
	var max_index := -1
	for goal in get_tree().get_nodes_in_group("goals"):
		max_index = max(max_index, goal.object_data.get("index", -1))
	return max_index

func _get_tooltip() -> Control:
	var label := Label.new()
	label.add_theme_stylebox_override("normal", preload("res://Nodes/Editor/GUI/TooltipPanel.tres"))
	label.text = str(object_data.index)
	return label

func _on_deleted():
	super._on_deleted()
	for goal in get_tree().get_nodes_in_group("goals"):
		if goal.object_data.get("index", -1) > object_data.index:
			goal.object_data.index -= 1
