extends "res://Resources/Anarchy/Scripts/UpperCaseButton.gd"

var current_option: int: set = set_option

var strings: PackedStringArray
var options: Array

signal option_selected(value)

func _ready() -> void:
	connect("pressed", Callable(self, "next_option"))

func next_option():
	self.current_option = (current_option + 1) % strings.size()
	emit_signal("option_selected", options[current_option])

func prev_option():
	self.current_option = (current_option - 1) % strings.size()
	emit_signal("option_selected", options[current_option])

func set_option(idx: int):
	current_option = idx
	self.small_text = strings[idx]

func assign_options(s: PackedStringArray, v: Array):
	assert(s.size() == v.size())
	strings = s
	options = v
	set_option(current_option)

func get_option():
	return options[current_option]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		prev_option()
