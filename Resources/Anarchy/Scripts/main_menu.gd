extends Control

signal option_changed

@onready var default_selected = $MarginContainer/HBoxContainer/MainMenuLeftPanel/Elements.get_child(0)
@onready var indicator = $MainMenuIndicator

func _ready():
	self.connect("option_changed", Callable(self, "_on_option_changed"))
	
	indicator.global_position.y = default_selected.global_position.y + 32


func _on_option_changed(what):
	indicator.get_node("AnimationPlayer").play("react1")
	indicator.global_position.y = what.global_position.y + 32
