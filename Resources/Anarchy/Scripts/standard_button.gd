extends "res://Resources/Anarchy/Scripts/UpperCaseButton.gd"

func _on_StandardButton_mouse_entered():
	self.self_modulate = Const.UI_MAIN_COLOR

func _on_StandardButton_mouse_exited():
		self.self_modulate = Color8(255,255,255,255)

func _on_StandardButton_focus_entered():
	self.self_modulate = Const.UI_MAIN_COLOR

func _on_StandardButton_focus_exited():
		self.self_modulate = Color8(255,255,255,255)

func _on_StandardButton_pressed():
		self.self_modulate = Color8(255,255,255,255)
