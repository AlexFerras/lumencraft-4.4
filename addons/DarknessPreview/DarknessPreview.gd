@tool
extends EditorPlugin

var button: BaseButton
var button2: BaseButton
var darkness
var glow

func _enter_tree() -> void:
	button = Button.new()
	button.flat = true
	button.tooltip_text = "Preview MapDarkness on current scene."
	button.toggle_mode = true
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
	button.add_theme_icon_override("icon", button.get_icon("PointLight2D", "EditorIcons"))
	button.connect("toggled", Callable(self, "toggle_darkness"))
	
	button2 = Button.new()
	button2.flat = true
	button2.tooltip_text = "Preview glow on current scene."
	button2.toggle_mode = true
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button2)
	button2.add_theme_icon_override("icon", button2.get_icon("WorldEnvironment", "EditorIcons"))
	button2.connect("toggled", Callable(self, "toggle_glow"))
	
	connect("scene_changed", Callable(self, "dupa"))

func dupa(dupa):
	button.button_pressed = false
	button2.button_pressed = false

func toggle_darkness(enable: bool):
	if enable and not darkness and not get_editor_interface().get_edited_scene_root().find_child("MapDarkness"):
		darkness = preload("res://Nodes/Map/Old/MapDarknessOld.tscn").instantiate()
		get_editor_interface().get_edited_scene_root().add_child(darkness)
	elif not enable and is_instance_valid(darkness):
		darkness.queue_free()
		darkness = null

func toggle_glow(enable: bool):
	if enable and not glow and not get_editor_interface().get_edited_scene_root().find_child("WorldEnvironment"):
		glow = WorldEnvironment.new()
		glow.environment = preload("res://Resources/Misc/MapEnvironment.tres")
		get_editor_interface().get_edited_scene_root().add_child(glow)
	elif not enable and is_instance_valid(glow):
		glow.queue_free()
		glow = null

func _exit_tree() -> void:
	button.queue_free()
	button2.queue_free()
