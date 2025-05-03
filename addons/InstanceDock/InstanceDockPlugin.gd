@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	dock = preload("res://addons/InstanceDock/InstanceDock.tscn").instantiate()
	dock.edited = false
	dock.plugin = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, dock)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()

func open_scene(scene: String):
	get_editor_interface().open_scene_from_path(scene)

func handles(object: Object) -> bool:
	return object is Node

func _forward_canvas_gui_input(event) -> bool:
	if not dock.can_draw.pressed:
		return false
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var possible = dock.scenes[dock.tabs.get_tab_title(dock.tabs.current_tab)]
		var node = load(possible[randi() % possible.size()]).instantiate()
		var parent = get_editor_interface().get_selection().get_selected_nodes().front() as Node2D
		if not parent:
			parent = get_editor_interface().get_edited_scene_root()
		
		node.position = parent.get_local_mouse_position()
		if dock.rand_rot.pressed:
			node.rotation = randf() * TAU
		node.scale = Vector2.ONE * randf_range(dock.min_sc.value, dock.max_sc.value)
		
		parent.add_child(node)
		node.owner = get_editor_interface().get_edited_scene_root()
		
		return true
	
	return false
