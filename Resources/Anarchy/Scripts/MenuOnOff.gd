extends "res://Resources/Anarchy/Scripts/UpperCaseButton.gd"

func _ready() -> void:
	connect("toggled", Callable(self, "refresh_text"))
	refresh_text()

func refresh_text(whatevs = null):
	if pressed:
		self.small_text = "ON"
	else:
		self.small_text = "OFF"
