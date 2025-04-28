@tool
extends Sprite2D

func _ready() -> void:
	add_to_group("dont_save")

func _process(delta):
	update_properites()

func update_properites():
	if not Engine.is_editor_hint():
		if is_nan(Utils.game.camera.get_camera_screen_center().y):
			return
		scale = Utils.game.camera.zoom * Save.config.downsample *1.01
		global_position = Utils.game.camera.get_camera_screen_center()
	
	material.set_shader_parameter("global_transform", get_global_transform())
