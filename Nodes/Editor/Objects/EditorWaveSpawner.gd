@tool
extends EditorObject

func _ready() -> void:
	add_to_group("wave_spawners")

func _init_data():
	defaults.radius = 100

func _refresh():
	queue_redraw()

func _configure(editor):
	var label := Label.new()
	label.text = get_id_text()
	editor.add_object_setting(label)
	
	editor.set_range_control(create_numeric_input(editor, "Radius", "radius", 1, 1000, true))

func _get_tooltip() -> Control:
	var label := Label.new()
	label.add_theme_stylebox_override("normal", preload("res://Nodes/Editor/GUI/TooltipPanel.tres"))
	label.text = get_id_text()
	return label

func get_id_text() -> String:
	return tr("Spawner ID: %s") % (get_tree().get_nodes_in_group("wave_spawners").find(self) + 1)

func _draw() -> void:
	if Utils.editor.hide_gizmos:
		return
	
	draw_arc(Vector2(), object_data.radius, 0, TAU, 32, Color.RED, 2)
