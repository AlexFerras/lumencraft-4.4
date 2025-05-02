extends "res://Resources/Anarchy/Scripts/UpperCaseButton.gd"

func _ready() -> void:
	call_deferred("adjust_root")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		call_deferred("adjust_root")

func adjust_root():
	get_parent().custom_minimum_size = size

func _on_MainMenuButton_mouse_entered():
	$AnimationPlayer.play("hover")
	owner.get_node("../%MainMenu").emit_signal('option_changed', self)

func _on_MainMenuButton_mouse_exited():
	$AnimationPlayer.play("hover_exit")
