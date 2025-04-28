@tool
extends EditorObject

func _init() -> void:
	can_rotate = true
	custom_condition_list = ["destroyed"]

func _ready() -> void:
	update_texture()

func _init_data():
	defaults.swarm = "Spider Swarm"
	defaults.max_enemy_count = 5
	defaults.spawn_interval = 5
	defaults.skin = 1
	defaults.max_hp = 150
	defaults.attack_base = false

func _configure(editor):
	var texture_rect := TextureRect.new()
	texture_rect.texture = get_enemy_texture()
	texture_rect.expand = true
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	editor.add_object_setting(texture_rect)
	
	var label := Label.new()
	label.autowrap = true
	label.text = "Select a monster from the enemy list and Ctrl+click this object to assign it."
	editor.add_object_setting(label)
	
	create_numeric_input(editor, "Max Enemies at Once", "max_enemy_count")
	var num = create_numeric_input(editor, "Spawn Interval", "spawn_interval", 0.1, 100)
	num.suffix = "s"
	num.step = 0.1
	create_numeric_input(editor, "Skin", "skin", 1, 3)
	create_numeric_input(editor, "Custom Nest HP", "max_hp", 1, 10000)
	create_checkbox(editor, "Attacks Base?", "attack_base")

func on_radius_changed(value):
	object_data.radius = value
	emit_signal("data_changed")
	_refresh()

func _get_tooltip() -> Control:
	var texture_rect := TextureRect.new()
	texture_rect.texture = get_enemy_texture()
	texture_rect.expand = true
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return texture_rect

func _push_object(object: EditorObject) -> bool:
	if object.object_type == "Enemy Swarm":
		object_data.swarm = "Swarm/" + object.object_name
		emit_signal("data_changed")
		tooltip_dirty = true
	elif object.object_type == "Enemy":
		object_data.swarm = object.object_name
		emit_signal("data_changed")
		tooltip_dirty = true
	return tooltip_dirty

func get_enemy_texture() -> Texture2D:
	return Utils.editor.get_object_icon("EnemiesGroup", object_data.swarm.trim_prefix("Swarm/"))

func _set_object_data_callback(value, field: String):
	super._set_object_data_callback(value, field)
	
	if field == "skin":
		update_texture()

func update_texture():
	var texture = load("res://Nodes/Objects/AlienNest/Alien_building_T00%s.png" % object_data.skin)
	icon.texture = Utils.create_atlas_frame(texture, Vector2(5, 3), 0)
