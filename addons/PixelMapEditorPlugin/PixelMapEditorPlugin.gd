@tool
extends EditorPlugin

var dock: Control
var editor: RefCounted
var pixel_map: PixelMap

func _enter_tree():
	dock = preload("res://addons/PixelMapEditorPlugin/Dock.tscn").instantiate()
	dock.editable = false
	dock.plugin = self
	
	editor = preload("res://addons/PixelMapEditorPlugin/PixelMapEditor.gd").new()
	editor.plugin = self
	editor.dock = dock
	editor.initialize()

func _exit_tree() -> void:
	if dock.is_visible_in_tree():
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, dock)
	dock.queue_free()

func handles(object: Object) -> bool:
	if object is PixelMap:
		return true
	
	pixel_map = null
	editor.set_pixel_map(pixel_map)
	return false

func edit(object: Object) -> void:
	if object == pixel_map:
		return
	
	pixel_map = object
	editor.set_pixel_map(pixel_map)

func _make_visible(visible: bool) -> void:
	if visible:
		add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, dock)
	elif dock.is_inside_tree():
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_SIDE_RIGHT, dock)

func _apply_changes():
	editor._apply_changes()

func _physics_process(delta: float) -> void:
	if editor != null:
		if typeof(editor) == TYPE_OBJECT and editor.has_method("process"):
			editor.process(delta)
		else:
			print("Editor object does not have a 'process' method.")
	else:
		print("Editor is Nil!")


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	return editor.gui_input(event)

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	editor.draw(overlay)
