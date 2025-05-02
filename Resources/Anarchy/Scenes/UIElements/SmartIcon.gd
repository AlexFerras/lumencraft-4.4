extends TextureRect

func _ready() -> void:
	update_config()

func update_config():
	self_modulate = Const.UI_MAIN_COLOR
