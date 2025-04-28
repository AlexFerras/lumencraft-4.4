@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init_data():
	super._init_data()
	defaults.player_id = -1

func _configure(editor):
	super._configure(editor)
	
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = "Player ID"
	set_label_color(label)
	hbox.add_child(label)
	
	var amount := SpinBox.new()
	amount.max_value = Const.PLAYER_LIMIT
	amount.value = object_data.player_id + 1
	amount.connect("value_changed", Callable(self, "set_player_id").bind(label))
	hbox.add_child(amount)
	
	editor.add_object_setting(hbox)

func set_player_id(id: int, label: Label):
	object_data.player_id = id - 1
	set_label_color(label)
	emit_signal("data_changed")

func set_label_color(label: Label):
	if object_data.player_id == -1:
		label.modulate = Color.GRAY
	else:
		label.modulate = Const.PLAYER_COLORS[object_data.player_id]
