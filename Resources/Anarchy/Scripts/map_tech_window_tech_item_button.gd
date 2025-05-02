extends Button

@onready var label := $Label

func _on_MapTechWindowTechItemButton_mouse_entered():
	self.self_modulate = Const.UI_MAIN_COLOR
	label.add_theme_color_override("font_color", Const.UI_MAIN_COLOR)


func _on_MapTechWindowTechItemButton_mouse_exited():
	self.self_modulate = Color8(255,255,255,255)
	label.remove_theme_color_override("font_color")


func _on_MapTechWindowTechItemButton_focus_entered():
	self.self_modulate = Const.UI_MAIN_COLOR
	label.add_theme_color_override("font_color", Const.UI_MAIN_COLOR)


func _on_MapTechWindowTechItemButton_focus_exited():
	self.self_modulate = Color8(255,255,255,255)
	label.remove_theme_color_override("font_color")
