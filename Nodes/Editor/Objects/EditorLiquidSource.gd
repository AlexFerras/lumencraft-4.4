@tool
extends EditorObject

const WATER_COLOR = Color.cornflower
const LAVA_COLOR = Color.ORANGE_RED

@export var color: Color

func _init_data():
	defaults.flowing = true
	defaults.radius = 100
	defaults.destroy_terrain = true

func set_liquid(liquid: String):
	if liquid == "Water":
		color = WATER_COLOR
	elif liquid == "Lava":
		color = LAVA_COLOR

func set_icon(i: Sprite2D):
	super.set_icon(i)
	
	match color:
		WATER_COLOR:
			icon.texture = load("res://Nodes/Editor/Icons/WaterSource.png")
		LAVA_COLOR:
			icon.texture = load("res://Nodes/Editor/Icons/LavaSource.png")

func _refresh():
	update()

func _configure(editor):
	create_checkbox(editor, "Is Flowing?", "flowing")
	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 512, true))
	
	if color == LAVA_COLOR:
		var checkbox := CheckBox.new()
		checkbox.text = "Destroy Terrain"
		checkbox.button_pressed = object_data.get("destroy_terrain", true)
		checkbox.connect("toggled", Callable(self, "set_destroy_terrain"))
		editor.add_object_setting(checkbox)

func set_destroy_terrain(destroy: bool):
	object_data.destroy_terrain = destroy
	emit_signal("data_changed")

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_arc(Vector2(), object_data.radius, 0, TAU, 32, color, 2)

func action_get_events() -> Array:
	return ["enable_flow", "disable_flow"]
