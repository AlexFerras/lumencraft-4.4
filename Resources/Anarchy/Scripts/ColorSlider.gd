extends TextureRect

@export var color_name: String
@export var component: int # (int, "H", "S", "V")

var value: float

signal value_changed(val)

func _ready() -> void:
	update_color()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_value_at(event.position)
	
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			set_value_at(event.position)
	
	if event.is_action("ui_left"):
		value -= 0.1
		accept_event()
	
	if event.is_action("ui_right"):
		value += 0.1
		accept_event()

func set_value_at(pos: Vector2):
	var color := get_assigned_color()
	var val := pos.x / size.x
	
	match component:
		0:
			color.h = val
		1:
			color.s = val
		2:
			color.v = val
	
	if is_inf(color.r) or is_inf(color.g) or is_inf(color.b) or is_nan(color.r) or is_nan(color.g) or is_nan(color.b):
		return
	
	match color_name:
		"UI_MAIN_COLOR":
			Save.config.ui_main_color = color
		"UI_SECONDARY_COLOR":
			Save.config.ui_secondary_color = color
		"BLOOD_COLOR":
			Save.config.blood_color = color
			update_map_blood_color()
	
	Save.save_config()
	Save.config.apply()
	get_parent().propagate_call("update_color")

func update_color():
	var color := get_assigned_color()
	
	match component:
		0:
			$Where.position.x = color.h * size.x
		1:
			texture.gradient.colors[0] = Color.from_hsv(color.h, 0, color.v)
			texture.gradient.colors[1] = Color.from_hsv(color.h, 1, color.v)
			$Where.position.x = color.s * size.x
		2:
			texture.gradient.colors[0] = Color.from_hsv(color.h, color.s, 0)
			texture.gradient.colors[1] = Color.from_hsv(color.h, color.s, 1)
			$Where.position.x = color.v * size.x

func update_map_blood_color():
	if Utils.game:
		if Utils.game.map.floor_surface2:
			Utils.game.map.floor_surface2.material.set_shader_parameter("hsvoffset4", Save.config.blood_color.h)

func get_assigned_color() -> Color:
	return Const.get(color_name)
